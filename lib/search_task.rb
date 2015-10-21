require 'curb'
require 'hpricot'

class SearchTask
  attr_accessor :last_results, :users, :terms, :url, :send_now, :results
  
  def initialize url, users, terms
    @users = users
    @terms = terms
    @url = url
    @send_now = false
    @results = Hash.new
  end
  

  def search        
    results = Hash.new
    web_page = Curl::Easy.perform(@url).body_str
    links = Hpricot(web_page).search("a")
    links.each do |link|
      @terms.uniq.each do |term|
        if link.inner_html.downcase.include? term
          @results[term] ||= Hash.new
          unless @results[term].keys.include?(link.inner_html)
            results[term] ||= Hash.new
            results[term][link.inner_html] = link.attributes["href"]
          end
        end
      end
    end
    results
  end

  def search_cycle 
      saved_results ||= Hash.new
      temp_results = search
      unless temp_results.empty?
        @last_results = Hash.new
        temp_results.each_key do |k|
          @last_results[k] = temp_results[k]
          @results[k] ||= Hash.new
          @results[k].merge!(temp_results[k])
        end
        @send_now = true
      end
      temp_results
  end
  
  
end
