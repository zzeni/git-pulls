class Options
  attr_accessor :extracted

  def initialize(command_line_args, env)
    @args = command_line_args
    @env = env

    @extracted = extract_options!(@args)
  end

  private
  def extract_options!(args)
    options = {}

    with_params = %w(user author base from to head title body format task)
    standalone = %w(mine)

    standalone.each do |arg|
      options[arg.to_sym] = true unless args.delete("--#{arg}").nil?
    end

    with_params.each do |arg|
      index = args.index "--#{arg}"
      unless index.nil?
        options[arg.to_sym] = args.delete_at(index+1)
        args.delete_at(index)
      end
    end

    check_options_compatibility!(options)
    format_options!(options)

    options
  end

  # Check for conflicts
  def check_options_compatibility!(options)
    raise_incompatible = lambda {|arg1, arg2| raise "Incompatible options used! You can specify only one of: --#{arg1}, --#{arg2} at a time."}

    [
      %w(user author),
      %w(user mine),
      %w(author mine),
      %w(mine global),
      %w(base to),
      %w(head from),
    ].each do |arg1, arg2|
      raise_incompatible.call(arg1, arg2) if options.has_key?(arg1) && options.has_key?(arg2)
    end

    if options.has_key?(:format)
      formats = %w(to_url to_browser)
      raise "Format can be one of: #{formats}" unless formats.include?(options[:format])
    end
  end

  def format_options!(options)
    options[:author] = options.delete(:user) if options.has_key?(:user)
    options[:author] = (options.delete(:mine) and @env[:git_login_name]) if options.has_key?(:mine)
    options[:base] = options.delete(:to) if options.has_key?(:to)
    options[:head] = options.delete(:from) if options.has_key?(:from)
  end
end
