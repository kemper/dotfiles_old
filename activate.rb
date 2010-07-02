#!/usr/bin/env ruby
require 'fileutils'

if ARGV[0] == "--help" || (ARGV[0] != 'mac' && ARGV[0] != 'linux')
  puts "Usage: ./activate.rb platform\n platform can be linux or mac."
  exit(0)
end

working_dir = File.expand_path(File.dirname(__FILE__))
home_dir = File.expand_path("~")

platform_specific = Dir.glob(File.join(working_dir,ARGV[0] || "mac","*"))
all_platforms = Dir.glob(File.join(working_dir,"all","*"))

(platform_specific + all_platforms).each do |filename|
  sym_link = File.join(home_dir,".#{File.basename(filename)}")

  FileUtils.rm sym_link if File.symlink?(sym_link) || File.exist?(sym_link)
  FileUtils.ln_s filename,sym_link
end

