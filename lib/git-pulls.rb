require 'rubygems'
require 'launchy'
require 'octokit'
require 'awesome_print'
require 'git-pulls/options'
require 'git-pulls/git_config'

class GitPulls

  #GIT_REMOTE = ENV['GIT_REMOTE'] || 'origin'

  class << self
    def start(args)
      GitPulls.new(args).run
    end
  end

  def initialize(args)
    @git_config = GitConfig.new

    url = @git_config[:remote][:origin][:url]
    token = @git_config[:token]

    @repo = Octokit::Repository.from_url url
    @client = Octokit::Client.new access_token: token

    @command = (args[0] && !args[0].start_with?('--')) ? args.shift : 'list'

    if ['merge', 'show', 'browse'].include? @command
      @pr_number = args.shift
    end

    @options = Options.new(args, git_login_name: current_user_login_name)
  #rescue Exception => error
  #  puts error
  #  usage
  #  exit 1
  end

  def run
    if @command && self.respond_to?(@command)
      self.send @command
    elsif %w(-h --help).include?(@command)
      usage
    else
      help
    end
  end


  ## COMMANDS ##

  def help
    puts "No command: #{@command}"
    puts "Try: open, list, show, merge, checkout, browse"
    puts "or call with '-h' for usage information"
  end

  def usage
    puts <<-USAGE
Usage: git pulls list [--mine|--author=GIT_LOGIN] [--format=[to_url|to_browser]]
   or: git pulls show <number> [--comments] [--full]
   or: git pulls browse <number>
   or: git pulls open [--from=HEAD] [--to=BASE] [--title=TITLE]
   or: git pulls merge <number>
    USAGE
  end

  def merge
    raise "Not implemented"
    #num = @args.shift
    #option = @args.shift
    #if p = pull_num(num)
    #  if p['head']['repository']
    #    o = p['head']['repository']['owner']
    #    r = p['head']['repository']['name']
    #  else # they deleted the source repo
    #    o = p['head']['user']['login']
    #    purl = p['patch_url']
    #    puts "Sorry, #{o} deleted the source repository, git-pulls doesn't support this."
    #    puts "You can manually patch your repo by running:"
    #    puts
    #    puts "  curl #{purl} | git am"
    #    puts
    #    puts "Tell the contributor not to do this."
    #    return false
    #  end
    #  s = p['head']['sha']
    #
    #  message = "Merge pull request ##{num} from #{o}/#{r}\n\n---\n\n"
    #  message += p['body'].gsub("'", '')
    #  cmd = ''
    #  if option == '--log'
    #    message += "\n\n---\n\nMerge Log:\n"
    #    puts cmd = "git merge --no-ff --log -m '#{message}' #{s}"
    #  else
    #    puts cmd = "git merge --no-ff -m '#{message}' #{s}"
    #  end
    #  exec(cmd)
    #else
    #  puts "No such number"
    #end
  end

  def show
    raise "Not implemented"

    #num = @args.shift
    #optiona = @args.shift
    #optionb = @args.shift
    #if p = pull_num(num)
    #  comments = []
    #  if optiona == '--comments' || optionb == '--comments'
    #    i_comments = Octokit.issue_comments("#{@user}/#{@repo}", num)
    #    p_comments = Octokit.pull_request_comments("#{@user}/#{@repo}", num)
    #    c_comments = Octokit.commit_comments(p['head']['repo']['full_name'], p['head']['sha'])
    #    comments = (i_comments | p_comments | c_comments).sort_by {|i| i['created_at']}
    #  end
    #  puts "Number   : #{p['number']}"
    #  puts "Label    : #{p['head']['label']}"
    #  puts "Creator  : #{p['user']['login']}"
    #  puts "Created  : #{p['created_at']}"
    #  puts
    #  puts "Title    : #{p['title']}"
    #  puts
    #  puts p['body']
    #  puts
    #  puts '------------'
    #  puts
    #  comments.each do |c|
    #    puts "Comment  : #{c['user']['login']}"
    #    puts "Created  : #{c['created_at']}"
    #    puts "File     : #{c['path']}:L#{c['line'] || c['position'] || c['original_position']}" unless c['path'].nil?
    #    puts
    #    puts c['body']
    #    puts
    #    puts '------------'
    #    puts
    #  end
    #  if optiona == '--full' || optionb == '--full'
    #    exec "git diff --color=always HEAD...#{p['head']['sha']}"
    #  else
    #    puts "cmd: git diff HEAD...#{p['head']['sha']}"
    #    puts git("diff --stat --color=always HEAD...#{p['head']['sha']}")
    #  end
    #else
    #  puts "No such number"
    #end
  end

  def browse
    pulls = get_pulls
    pull = pulls.find {|p| p.number == @pr_number.to_i}

    if pull
      Launchy.open(_extract_url(pull))
    else
      puts "No such number: #{@pr_number}"
    end
  end

  def list
    pulls = get_pulls

    info_line = "Listing Pull Requests for #{@repo}"

    if @options.extracted[:author]
      pulls.select! { |p| p.user.login == @options.extracted[:author] }
      info_line << ", authored_by #{@options.extracted[:author]}"
    end

    if @options.extracted[:task]
      pulls.select! { |p| p.extended_title =~ /#{@options.extracted[:task]}/ }
      info_line << ", mentioning task: #{@options.extracted[:task]}"
    end

    puts "\n" + info_line + "\n\n"

    if pulls.size == 0
      puts ' -- no pull requests --'
    elsif @options.extracted[:format]
      self.send("list_#{@options.extracted[:format]}", pulls)
    else
      default_list(pulls)
    end

    puts
  end

  def make_pull_request
    head = @options.extracted[:head] || git_branch
    base = @options.extracted[:base] || 'master'

    title = @options.extracted[:title] || head
    body = @options.extracted[:body] || "Merge #{head} into #{base}"

    confirmation_notice = <<EOT
A pull request will be opened with the following settings:
    base (source branch): #{base}
    head (destination branch): #{head}
    title: #{title}
    body: #{body}
Open a pull request from? [y|N]
EOT

    if confirm?(confirmation_notice)
      pr = @client.create_pull_request(@repo, base, head, title, body)
      if pr.present?
        default_list([pr])
      else
        puts "Error opening a pull request"
      end
    end
  end
  alias_method :open, :make_pull_request

  def current_user_name
    @client.user.name
  end

  def current_user_login_name
    @client.user.login
  end

  def current_user_display_name
    "#{current_user_name} (#{current_user_login_name})"
  end

  def confirm?(message)
    puts message
    answer = STDIN.readline
    %w(y yes).include? answer.to_s.downcase
  end

  private

  def get_pulls
    pulls = @client.pulls @repo
    pulls.each { |p| p[:extended_title] = "[#{p.head.ref}] #{p.title}" }
  end

  # DISPLAY HELPER METHODS #

  def left(info, size)
    clean(info)[0, size].ljust(size)
  end

  def right(info, size)
    clean(info)[0, size].rjust(size)
  end

  def clean(info)
    info.to_s.gsub("\n", ' ')
  end

  def default_list(pulls)
    puts [
           left('number', 8),
           left('user', 15),
           left('title', 55),
           left('head', 30),
           left('base', 30),
           left('created_at', 25)
         ].join(" ")

    puts '-' * 165

    pulls.each do |pull|
      line = []
      line << left(pull.number, 8)
      line << left(pull.user.login, 15)
      line << left(pull.title, 55)
      line << left(pull.head.ref, 30)
      line << left(pull.base.ref, 30)
      line << left(pull.created_at, 25)

      puts line.join(" ")
    end
  end

  def list_to_url(pulls)
    pulls.each { |pull| puts " -> #{_extract_url(pull)} (#{pull.extended_title})" }
  end

  def list_to_browser(pulls)
    pulls.each { |pull| Launchy.open(_extract_url(pull)) }
    default_list(pulls)
  end

  def _extract_url(pull)
    pull._links.html.href
  end

  def git_branch
    %x(git rev-parse --abbrev-ref HEAD).chomp
  end
end
