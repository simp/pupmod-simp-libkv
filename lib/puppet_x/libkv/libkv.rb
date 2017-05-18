# vim: set expandtab ts=2 sw=2:
@classes = {}
@urls = {}
@default_url = ""
def classes()
  @classes
end
def classes=(value)
  @classes = value
end
def urls()
  @urls
end
def urls=(value)
  @urls = value
end
def default_url()
  @default_url
end
def default_url=(value)
  @default_url = value
end

def load(name, &block)
  @classes[name] = Class.new(&block)
end
def parseurl(url)
  hash = {}
  colonsplit = url.split(":");
  hash['provider'] = colonsplit[0].split("+")[0];
  return hash
end
def symbol_table()
  {
    :params => {
      'key' => "KeySpecification",
      'previous' => "Hash",
      'url' => "String",
      'auth' => "Hash",
      'value' => "",
    },
    :get => {
      'key' => "required",
    },
    :put => {
      'key' => "required",
      'value' => "required",
    },
    :delete => {
      'key' => "required",
    },
    :exists => {
      'key' => "required",
    },
    :list => {
      'key' => "required",
    },
    :deletetree => {
      'key' => "required",
    },
    :atomic_create => {
      'key' => "required",
      'value' => "required",
    },
    :atomic_delete => {
      'key' => "required",
      'previous' => "required",
    },
    :atomic_get => {
      'key' => "required",
    },
    :atomic_put => {
      'key' => "required",
      'value' => "required",
      'previous' => "required",
    },
    :atomic_list => {
      'key' => "required",
    },
  }
end
def sanitize_input(symbol, params)
  if (params.class.to_s != "Hash")
    raise "parameter 0 needs to be a Hash, found #{params.class.to_s}"
  end
  table = symbol_table
  if (table.key?(symbol))
    function_parameters = table[symbol]
    function_parameters.each do |name, status|
      found = params.key?(name)
      case status
      when "required"
        if (found == false)
          raise "parameter: #{name} not found"
        end
      end
      if (found == true)
        definition = table[:params][name]
        case definition
        when ""
          if (params[name] == nil)
            raise "parameter #{name} should not be nil"
          end
        when "KeySpecification"
          unless (params[name].class.to_s == "String")
            raise "parameter #{name} should be String, found #{params[name].class.to_s}"
          end
          regex = /^\/[a-zA-Z0-9._\-\/]*$/
          error_msg = "the value of '#{name}': '#{params[name]}' does not match regex '#{regex}'"
          unless (regex =~ params[name])
            raise error_msg
          end

        else
          unless (params[name].class.to_s == definition)
            raise "parameter #{name} should be #{definition}, found #{params[name].class.to_s}"
          end
        end
      end
    end
  end
end
def method_missing(symbol, url, auth, *args, &block)
  sanitize_input(symbol, args[0])
  # For safety make a new hash. This doesn't prevent side effects
  # but reduces them somewhat
  params = args[0].dup
  nargs = [ params ]
  # ddb hook for testing.
  # if (params['dd'] == true)
  #   binding.pry
  # end

  unless (params.key?("serialize"))
    params["serialize"] = true
  end
  serialize = params["serialize"]
  if (params.key?("mode") == false or params["mode"] == "" or params["mode"] == nil)
    params["mode"] = 'puppet'
  end

  if (auth == nil)
    auth_hash = ""
  else
    auth_hash = auth.hash
  end
  instance = url + "@" + auth_hash.to_s
  if (urls[instance] == nil)
    urlspec = parseurl(url)
    provider = urlspec['provider']
    urls[instance] = classes[provider].new(url, auth)
  end
  object = urls[instance];
  case symbol
  when :put
    if (serialize == true)
      meta = get_metadata(params, object)
      params["value"] = pack(meta, params["value"])
    end
    retval = object.send(symbol, *nargs, &block);
  when :atomic_put
    if (serialize == true)
      meta = get_metadata(params, object)
      params["value"] = pack(meta, params["value"])
    end
    retval = object.send(symbol, *nargs, &block);
  when :atomic_create
    if (serialize == true)
      meta = get_metadata(params, object)
      params["value"] = pack(meta, params["value"])
    end
    retval = object.send(symbol, *nargs, &block);
  else
    retval = object.send(symbol, *nargs, &block);
  end

  case symbol
  when :get
    if (serialize == true and params["key"] !~ /.*\.meta$/)
      metadata = get_metadata(params, object);
      return unpack(metadata,retval)
    else
      return retval
    end
  when :atomic_get
    if (serialize == true and params["key"] !~ /.*\.meta$/)
      metadata = get_metadata(params, object);
      if (retval.key?("value"))
        value = unpack(metadata,retval["value"])
        retval["value"] = value
      end
      return retval
    else
      return retval
    end
  when :list
    filtered_list = {}
    retval.each do |entry, value|
      unless (entry =~ /.*\.meta$/)
        if (serialize == true)
          unless (params['key'] == '/')
            metadata = get_metadata(params.merge({ "key" => "#{params['key']}/#{entry}" }), object)
          else
            metadata = get_metadata(params.merge({ "key" => "/#{entry}" }), object)
          end
          filtered_list[entry] = unpack(metadata, value)
        else
          filtered_list[entry] = value
        end
      end
    end
    return filtered_list
  when :atomic_list
    filtered_list = {}
    retval.each do |entry, value|
      unless (entry =~ /.*\.meta$/)
        if (serialize == true)
          unless (params['key'] == '/')
            metadata = get_metadata(params.merge({ "key" => "#{params['key']}/#{entry}" }), object)
          else
            metadata = get_metadata(params.merge({ "key" => "/#{entry}" }), object)
          end
          value["value"] = unpack(metadata, value["value"])
          filtered_list[entry] = value
        else
          filtered_list[entry] = value
        end
      end
    end
    return filtered_list
  else
    return retval
  end
end
def get_metadata(params, object)
  meta = []
  meta[0] = params.dup
  meta[0]["key"] = "#{params['key']}.meta"
  # XXX FIXME: Make this atomic
  if (object.send(:exists, *meta))
    metadata = object.send(:get, *meta)
    retval = JSON.parse(metadata)
  else
    retval = {}
    retval["format"] = "json"
    retval["mode"] = params["mode"]
    if (params.key?("value"))
      retval["type"] = puppetype(params["value"])
      meta[0]["value"] = retval.to_json
      object.send(:put, *meta);
    else
      retval["type"] = "String"
    end
  end
  return retval
end
def pack(meta, value)
  unless (meta["type"] == "String")
    # JSON objects need to be real objects, or else the parser blows up. So wrap in a hash
    encapsulation = { "value" => value }
    encapsulation.to_json
  else
    value
  end
end
def unpack(meta, value)
  retval = value
  case meta["mode"]
  when "puppet"
    unless (meta["type"] == "String")
      case meta["format"]
      when "json"
        unless value == nil
          object = JSON.parse(value)
          retval = object["value"]
        end
      else
        raise "Unknown format: #{meta["format"]}"
      end
    end
  else
    raise "Unknown mode: #{meta["mode"]}"
  end
  return retval
end
def puppetype(klass)
  retval = klass.class.to_s
  case klass.class.to_s
  when "Fixnum"
    retval = "Integer"
  when "Float"
    retval = "Float"
  when "Array"
    retval = "Array"
  when "Hash"
    retval = "Hash"
  when "TrueClass"
    retval = "Boolean"
  when "FalseClass"
    retval = "Boolean"
  end
  retval
end

# Every file in lib/puppet_x/libkv/*_provider.rb is assumed
# to contain a libkv backend provider, and we load them in.
#
# Every provider uses $LIBKV.load() to actually define itself,
# which results in catalog.libkv.classes['providername'] to return
# the Class that implements the provider.
providerglob = File.dirname(File.dirname(File.dirname(File.dirname(File.dirname(__FILE__))))) + "/*/lib/puppet_x/libkv/*_provider.rb"
Dir.glob(providerglob) do |filename|
  self.instance_eval File.read(filename), filename
end
