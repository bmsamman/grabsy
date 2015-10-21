require './lib/search_task'
require 'mail'
require 'logger'
require 'yaml'

$logger = Logger.new "grabsy.log", "weekly"

config = YAML::load( File.open( './config.yml' ) )
mail_config = config['mail']
d_config = mail_config['defaults']['delivery_method']
r_config = mail_config['defaults']['retriever_method']

Mail.defaults do
   delivery_method mail_config['delivery_protocal'], d_config

   retriever_method mail_config['retriever_protocal'], r_config

end

@mail = Mail.new do
       from mail_config["default_from_adress"]
    subject mail_config["default_subject"]
end
@terms = config["initial_terms"]
@last_results = Hash.new
@users = config["send_list"]

def change_array task, action, array, values
  if action == "add"
    task.send("#{array}=", (task.send("#{array}") + values).uniq) 
  elsif action == "remove"
    task.send("#{array}=", task.send("#{array}") - values) 
  end
  $logger.info "Array is now: " + task.send("#{array}").to_s
end
  
def send_results task
  results = task.last_results
  findings = []
  message = ""
  results.each do |key, value|
    findings.push "#{results[key].size} new matches for #{key}"
    message +=  "\n\n#{results[key].size} results for #{key}:"
    value.each{|k,v| message += "\n====> #{k}: #{v}" }
  end
  $logger.info message
  @mail.body = message
  @mail.subject = "CLBot Found: #{findings.join(', ')}"
  task.users.map{|user| @mail.to = user; @mail.deliver ; $logger.info "***Sent message to #{user}***"}
end

def check_mail task, accepted_users
  emails = Mail.all
  emails.each do |mail|
    action_words = mail.subject.split " "
    if action_words.size >= 3 and accepted_users.include?(mail.from.first)
      change_array(task, action_words[0], action_words[1], action_words[2..-1]) if task.send("#{action_words[1]}") 
    elsif mail.subject.downcase == "list"
      message = "Users: #{task.users.join(", ")}\nTerms: #{task.terms.join(", ")}"
      $logger.info "Sending list response to: #{mail.from.first}"
      @mail.body = message
      @mail.subject = "CLBot list response"
      @mail.to = mail.from.first
      @mail.deliver
    elsif mail.subject.downcase == 'resend'
      @send_now = true
    end  
    $logger.info "Parsed subject: #{mail.subject}"
  end
  Mail.delete_all unless emails.size == 0
end


def start_engine urls, accepted_users
  tasks = Hash.new
  urls.each {|url| tasks[url] = SearchTask.new(url, @users, @terms)}
  while true do
    tasks.values.each do |task| 
      begin
        check_mail task, accepted_users
        task.search_cycle
        @send_now ||= task.send_now
        if @send_now
          send_results task
          @send_now = false
          task.send_now = false
        end
        sleep 10
#      rescue Exception => e
#        $logger.info "Exception occurred" + e.message
      end
    end
  end
end

start_engine config["urls"], mail_config["accept_commands_only_from"]
