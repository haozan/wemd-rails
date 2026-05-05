require 'net/http'
require 'json'
require 'uri'
require 'down'
require 'net/http/post/multipart'

module Wechat
  class SyncService
    API_URL = "https://api.weixin.qq.com/cgi-bin"

    class SyncError < StandardError; end

    def initialize(user)
      @user = user
      @app_id = user.wechat_app_id
      @app_secret = user.wechat_app_secret
    end

    def ready?
      @app_id.present? && @app_secret.present?
    end

    # 获取 Access Token，自带简单的缓存机制（官方建议缓存，有效期 2 小时）
    def access_token
      cache_key = "wechat_access_token_#{@app_id}"
      token = Rails.cache.read(cache_key)
      return token if token.present?

      url = URI("#{API_URL}/token?grant_type=client_credential&appid=#{@app_id}&secret=#{@app_secret}")
      response = Net::HTTP.get_response(url)
      result = JSON.parse(response.body)

      if result["errcode"] && result["errcode"] != 0
        handle_error(result)
      end

      # 提前 5 分钟过期
      expires_in = result["expires_in"].to_i - 300
      Rails.cache.write(cache_key, result["access_token"], expires_in: expires_in)
      
      result["access_token"]
    end

    # 通过图文素材上传接口，将我们的网络图片转换为微信能用的 mmbiz URL
    # 这个接口不占用公众号每天的素材配额，专门用来传正文图片的。
    def upload_image_for_article(image_url)
      uri = URI("#{API_URL}/media/uploadimg?access_token=#{access_token}")
      
      # 使用 Down 下载图片到临时文件
      tempfile = Down.download(image_url)
      
      request = Net::HTTP::Post::Multipart.new(
        uri.path + "?#{uri.query}",
        { "media" => UploadIO.new(tempfile, tempfile.content_type, tempfile.original_filename) }
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(request)
      result = JSON.parse(response.body)

      tempfile.close
      tempfile.unlink

      if result["errcode"] && result["errcode"] != 0
        handle_error(result)
      end

      result["url"]
    rescue Down::Error => e
      raise SyncError, "图片下载失败: #{e.message} (#{image_url})"
    end

    # 上传永久素材图片作为封面（草稿一定要用 MediaID）
    def upload_material_image(image_url)
      uri = URI("#{API_URL}/material/add_material?access_token=#{access_token}&type=image")
      
      tempfile = Down.download(image_url)
      
      request = Net::HTTP::Post::Multipart.new(
        uri.path + "?#{uri.query}",
        { "media" => UploadIO.new(tempfile, tempfile.content_type, tempfile.original_filename) }
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(request)
      result = JSON.parse(response.body)

      tempfile.close
      tempfile.unlink

      if result["errcode"] && result["errcode"] != 0
        handle_error(result)
      end

      result["media_id"]
    rescue Down::Error => e
      raise SyncError, "封面图片下载失败: #{e.message} (#{image_url})"
    end

    # 同步整个文档到微信草稿箱
    def push_draft(document, thumb_media_id)
      # 第一阶段：将 Markdown 转换为 HTML（如果它原本就是 HTML 会保持基本原样，但考虑到数据都是 markdown_text）
      require 'commonmarker'
      html_content = Commonmarker.to_html(document.content || "", options: {
        render: { unsafe: true }, # 允许渲染行内 HTML 如 <img> <br>
        extension: {
          header_ids: nil  # 关闭 heading 自动锚点，微信草稿不允许这种 <a href="#..."> 链接，会触发 45166
        }
      })

      # 第二阶段：解析 HTML 并替换所有 img，将其转成微信特有的 mmbiz_url
      processed_content = process_html_images(html_content)

      # 微信要求 content 不能全空白，且要求一定的标签包裹。补一个极简的包裹以防万一内容为空报错
      processed_content = "<p>空草稿</p>" if processed_content.to_s.strip.empty?
      
      # 避免有些转换库在最外层缺少块级元素被微信嫌弃非法内容
      unless processed_content.include?('<p') || processed_content.include?('<div') || processed_content.include?('<section')
        processed_content = "<p>#{processed_content}</p>"
      end
      
      # NOTE: 针对 45166 invalid content，微信极度严格，在 JSON 编码时不能有双引号错误转义或特殊 HTML 转义。
      # 而且内容外部经常需要一个基础标签，如果在生成 HTML 时失去了最外层的换行或者什么，也会被拦截。
      
      # 第三阶段：提交草稿
      uri = URI("#{API_URL}/draft/add?access_token=#{access_token}")
      
      payload = {
        articles: [
          {
            title: document.title,
            content: processed_content,
            thumb_media_id: thumb_media_id,
            author: @user.name,
            need_open_comment: 0,
            only_fans_can_comment: 0
          }
        ]
      }

      req = Net::HTTP::Post.new(uri)
      req.content_type = 'application/json; charset=utf-8'
      json_body = payload.to_json
      req.body = json_body

      # ===== 调试日志：打印真正发给微信的完整 Payload =====
      Rails.logger.warn("[WECHAT_DEBUG] Title: #{document.title.inspect}")
      Rails.logger.warn("[WECHAT_DEBUG] Author: #{@user.name.inspect}")
      Rails.logger.warn("[WECHAT_DEBUG] Thumb Media ID: #{thumb_media_id.inspect}")
      Rails.logger.warn("[WECHAT_DEBUG] Content Length: #{processed_content.bytesize} bytes")
      Rails.logger.warn("[WECHAT_DEBUG] Content (first 2000 chars): #{processed_content[0, 2000]}")
      Rails.logger.warn("[WECHAT_DEBUG] JSON Body (first 3000 chars): #{json_body[0, 3000]}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(req)
      result = JSON.parse(response.body)

      Rails.logger.warn("[WECHAT_DEBUG] Response: #{response.body}")

      if result["errcode"] && result["errcode"] != 0
        handle_error(result)
      end

      result["media_id"]
    end

    private

    # 用 Nokogiri 解析 HTML，找到所有的 img 并走微信上传
    def process_html_images(html_content)
      doc = Nokogiri::HTML::DocumentFragment.parse(html_content)

      # 兜底清理：删除 heading 自动锚点产生的 <a class="anchor" href="#xxx">...</a>
      # 微信 45166 invalid content 的罪魁祸首之一
      doc.css('a').each do |a|
        href = a['href'].to_s
        if href.start_with?('#') || a['class'].to_s.include?('anchor')
          # 保留内部文本，移除标签本身
          a.replace(a.children)
        end
      end

      doc.css('img').each do |img|
        src = img['src']
        next if src.blank?
        # 如果已经是微信图片，跳过
        next if src.include?('mmbiz.qpic.cn') || src.include?('mmbiz.qlogo.cn')
        
        # 兼容相对路径（拼接主机名）
        full_url = format_image_url(src)
        
        begin
          wechat_url = upload_image_for_article(full_url)
          img['src'] = wechat_url
        rescue => e
          Rails.logger.error "Wechat Image Upload Failed: #{e.message}"
          # 图片上传失败时策略：保留原图，但是微信侧可能由于防盗链无法显示
        end
      end

      # Nokogiri 转换出来的 html 默认可能有一些不必要的格式，强制按 UTF-8 转出来
      doc.to_html(encoding: 'UTF-8')
    end

    def format_image_url(url)
      return url if url.start_with?('http')
      
      # 如果是相对路径，需要拼上服务器前缀 （可以通过环境变量配置）
      base_url = ENV.fetch('HOST_URL', 'http://localhost:3000')
      URI.join(base_url, url).to_s
    end

    def handle_error(result)
      error_msg = case result["errcode"]
                  when 40001 then "AppSecret 错误或者 AccessToken 无效。"
                  when 40013 then "AppID 不合法。"
                  when 40164 then "IP 未在微信公众号后台白名单中！(极其重要)"
                  when 41004 then "AppSecret 缺少。"
                  when 41005 then "缺少多媒体文件数据。"
                  when 45009 then "接口调用超过公众号的每日限额。"
                  else "微信接口错误: #{result['errmsg']} (错误码: #{result['errcode']})"
                  end
      raise SyncError, error_msg
    end
  end
end