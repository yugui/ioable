module ConvertHelper
  module_function
  def try_convert(obj, expected_class, convert_method)
    if obj.kind_of?(expected_class)
      return obj
    elsif obj.respond_to?(convert_method)
      orig, obj = obj, obj.send(convert_method)
      return obj if obj.kind_of?(expected_class)
    end

    raise TypeError, "expected #{expected_class} but got #{obj.class}"
  end
end
