# Flexible Route Helpers - System-wide route name compatibility patch
#
# Problem: Rails generates different path helper names for different route types:
# - Standard routes: api_v1_products_path (namespace_resource)
# - Collection routes: search_api_v1_products_path (action_namespace_resource)
#
# AI often gets confused and uses the wrong order. This patch makes both work.
#
# Examples that will both work after this patch:
# - api_v1_search_products_path ✓ (wrong order, but will work)
# - search_api_v1_products_path ✓ (correct order, will work)

module FlexibleRouteHelpers
  def method_missing(method_name, *args, &block)
    # Only intercept *_path and *_url methods
    if method_name.to_s.end_with?('_path', '_url')
      alternative_method = find_alternative_route_helper(method_name)

      if alternative_method
        # Found an alternative! Use it silently
        send(alternative_method, *args, &block)
      else
        # No alternative found, call original method_missing
        super
      end
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    if method_name.to_s.end_with?('_path', '_url')
      alternative = find_alternative_route_helper(method_name)
      !alternative.nil? || super
    else
      super
    end
  end

  private

  def find_alternative_route_helper(method_name)
    method_str = method_name.to_s
    suffix = method_str.end_with?('_path') ? '_path' : '_url'

    # Remove suffix to get the parts
    name_parts = method_str.gsub(/_(path|url)$/, '').split('_')

    # Get all available route names (cached)
    available_routes = route_names_cache

    # Try different permutations of the parts
    permutations = generate_route_permutations(name_parts)

    permutations.each do |perm|
      alternative = "#{perm.join('_')}#{suffix}"
      return alternative.to_sym if available_routes.include?(alternative)
    end

    nil
  end

  def route_names_cache
    if Rails.env.development?
      # Development: no cache, always build fresh to catch route changes
      build_route_names_set
    else
      # Production: cache forever for performance
      @route_names_cache ||= build_route_names_set
    end
  end

  def build_route_names_set
    routes = []
    Rails.application.routes.routes.each do |route|
      if route.name
        routes << "#{route.name}_path"
        routes << "#{route.name}_url"
      end
    end
    routes.to_set
  end

  def generate_route_permutations(parts)
    return [] if parts.empty?

    permutations = []

    # Strategy 1: Move first element to different positions
    # Handles: api_v1_search_products -> search_api_v1_products
    if parts.length > 1
      first = parts.first
      rest = parts[1..-1]

      (1..rest.length).each do |i|
        new_parts = rest[0...i] + [first] + rest[i..-1]
        permutations << new_parts
      end
    end

    # Strategy 2: Move elements after common namespace patterns
    # Handles patterns like: namespace_namespace_action_resource
    if parts.length >= 3
      # Look for common namespace prefixes (api, v1, v2, admin, etc.)
      namespace_prefixes = ['api', 'v1', 'v2', 'v3', 'admin']

      # Find where namespaces end
      namespace_end = 0
      parts.each_with_index do |part, idx|
        if namespace_prefixes.include?(part) || part.match?(/^v\d+$/)
          namespace_end = idx
        else
          break if namespace_end > 0
        end
      end

      if namespace_end > 0 && namespace_end < parts.length - 1
        # Try moving parts around the namespace boundary
        namespaces = parts[0..namespace_end]
        action_and_resource = parts[(namespace_end + 1)..-1]

        if action_and_resource.length > 1
          # Try: [action, namespaces, resource]
          action = action_and_resource[0..-2]
          resource = action_and_resource[-1]
          permutations << action + namespaces + [resource]

          # Try: [action, namespaces, remaining]
          action_first = action_and_resource[0]
          remaining = action_and_resource[1..-1]
          permutations << [action_first] + namespaces + remaining
        end
      end
    end

    permutations.uniq
  end
end

# Patch ActionDispatch::Routing::UrlFor to include our flexible helpers
# This makes it work everywhere: controllers, views, helpers, console, tests
Rails.application.config.to_prepare do
  ActionDispatch::Routing::UrlFor.prepend(FlexibleRouteHelpers)
end
