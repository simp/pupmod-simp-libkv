# vim: set expandtab ts=2 sw=2:
#
# @author Dylan Cochran <dylan.cochran@onyxpoint.com>
Puppet::Functions.create_function(:'libkv::delete') do
  # @param parameters [Hash] Hash of all parameters
  # 
  # @param key [String] string of the key to retrieve
  #
  # @return [Any] The value in the underlying backing store
  #
  #
  dispatch :delete do
    param 'Hash', :parameters
  end



  
    dispatch :delete_v1 do
    
      
        param "String", :parameters
      
    
    end
    def delete_v1(key)
     params = {}
     
      
        params['key'] = key
      
    
    delete(params)
    end
  

def delete(params)
    if (closure_scope.class.to_s == 'Puppet::Parser::Scope') 
      catalog = closure_scope.find_global_scope.catalog
    else
      if ($__LIBKV_CATALOG == nil)
        catalog = Object.new
        $__LIBKV_CATALOG = catalog
      else
        catalog = $__LIBKV_CATALOG
      end
    end
    begin
      find_libkv = catalog.libkv
    rescue
      filename = File.dirname(File.dirname(File.dirname(File.dirname("#{__FILE__}")))) + "/puppet_x/libkv/loader.rb"
      if File.exists?(filename)
        catalog.instance_eval(File.read(filename), filename)
        find_libkv = catalog.libkv
      else
        raise Exception
      end
    end
    libkv = find_libkv
    if params.key?('url')
      url = params['url']
    else
      url = call_function('lookup', 'libkv::url', { 'default_value' => 'mock://'})
    end
    params["url"] = url
    
    if params.key?('auth')
      auth = params['auth']
    else
      auth = call_function('lookup', 'libkv::auth', { 'default_value' => nil })
    end
    params["auth"] = auth
    if (params["softfail"] == true)
      begin
        retval = libkv.delete(url, auth, params);
      rescue
        retval = false
      end
    else
      retval = libkv.delete(url, auth, params);
     end
    return retval;
  end
end

