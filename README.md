# ClackyAI Rails7 starter

The template for ClackyAI

## Installation

Install dependencies:

* postgresql

    ```bash
    $ brew install postgresql
    ```

    Ensure you have already initialized a user with username: `postgres` and password: `postgres`( e.g. using `$ createuser -d postgres` command creating one )

* rails 7

    Using `rbenv`, update `ruby` up to 3.x, and install `rails 7.x`

    ```bash
    $ ruby -v ( output should be 3.x )

    $ gem install rails

    $ rails -v ( output should be rails 7.x )
    ```

* npm

    Make sure you have Node.js and npm installed

    ```bash
    $ npm --version ( output should be 8.x or higher )
    ```

Install dependencies, setup db:
```bash
$ ./bin/setup
```

Start it:
```
$ bin/dev
```

## 公众号排版档位

编辑器真实预览、复制到公众号、同步草稿箱和 Personal API 共用同一套排版档位：

| `typography_profile` | 正文 | 行高 | 用途 |
| --- | --- | --- | --- |
| `compact_15` | 15px | 1.70 | 信息密度优先 |
| `standard_16` | 16px | 1.75 | 通用内容 |
| `readable_17` | 17px | 1.75 | 长文舒适阅读（默认） |

`POST /api/v1/articles/preview` 可在发布前无副作用地返回最终内联 HTML 和
`effective_typography`；`POST /api/v1/articles/push_to_wechat` 接受相同的
`typography_profile` 字段。显式 API 档位优先于账号默认值，账号未设置时使用
`readable_17`。

## Admin dashboard info

This template already have admin backend for website manager, do not write business logic here.

Access url: /admin

Default superuser: admin

Default password: admin

## Tech stack

* Ruby on Rails 7.x
* Tailwind CSS 3 (with custom design system)
* Hotwire Turbo (Drive, Frames, Streams)
* Stimulus
* ActionCable
* figaro
* postgres
* active_storage
* kaminari
* puma
* rspec
