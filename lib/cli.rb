#!/usr/bin/env ruby
require "date"
require "rubygems"
require "bundler/setup"
require "thor"

class CLI < Thor
  include Thor::Actions

  desc "new", "Create a new blog post"
  def new
    @publish_date = Date.today.strftime("%F")
    @title = ask "What's the title?"
    @author = ask "What's your name?"
    file_name = "#{@publish_date}-#{@title.downcase.tr(" ".freeze, "-".freeze)}.markdown"

    template "templates/blog.erb", "_posts/#{file_name}"
  end

  def self.source_root
    File.dirname(__FILE__)
  end
end

CLI.start(ARGV)
