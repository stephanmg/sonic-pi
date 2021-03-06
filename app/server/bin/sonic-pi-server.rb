#!/usr/bin/env ruby
#--
# This file is part of Sonic Pi: http://sonic-pi.net
# Full project source: https://github.com/samaaron/sonic-pi
# License: https://github.com/samaaron/sonic-pi/blob/master/LICENSE.md
#
# Copyright 2013, 2014 by Sam Aaron (http://sam.aaron.name).
# All rights reserved.
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as this
# notice is included.
#++

require 'cgi'

require_relative "../core.rb"
require_relative "../sonicpi/lib/sonicpi/studio"
require_relative "../sonicpi/lib/sonicpi/spider"
require_relative "../sonicpi/lib/sonicpi/spiderapi"
require_relative "../sonicpi/lib/sonicpi/server"
require_relative "../sonicpi/lib/sonicpi/util"
require_relative "../sonicpi/lib/sonicpi/oscencode"

require 'multi_json'

include SonicPi::Util

server_port = ARGV[0] ? ARGV[0].to_i : 4557
client_port = ARGV[1] ? ARGV[1].to_i : 4558
puts "Using protocol: UDP"

ws_out = Queue.new
gui = OSC::Client.new("localhost", client_port)
encoder = SonicPi::OscEncode.new(true)

begin
  osc_server = OSC::Server.new(server_port)
rescue Exception => e
  m = encoder.encode_single_message("/exited", ["Failed to open server port " + server_port.to_s + ", is scsynth already running?"])
  gui.send_raw(m)
  exit
end


at_exit do
  m = encoder.encode_single_message("/exited")
  gui.send_raw(m)
end

user_methods = Module.new
name = "SonicPiSpiderUser1" # this should be autogenerated
klass = Object.const_set name, Class.new(SonicPi::Spider)

klass.send(:include, user_methods)
klass.send(:include, SonicPi::SpiderAPI)
#klass.send(:include, SonicPi::Mods::SPMIDI)
klass.send(:include, SonicPi::Mods::Sound)
begin
  sp =  klass.new "localhost", 4556, ws_out, 5, user_methods
rescue Exception => e
  puts "Failed to start server: " + e.message
  m = encoder.encode_single_message("/exited", [e.message])
  gui.send_raw(m)
  exit
end

osc_server.add_method("/run-code") do |payload|
  begin
#    puts "Received OSC: #{payload}"
    code = payload.to_a[0]
    sp.__spider_eval code
  rescue Exception => e
    puts "Received Exception!"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/save-and-run-buffer") do |payload|
  begin
#    puts "Received save-and-run-buffer: #{payload.to_a}"
    args = payload.to_a
    buffer_id = args[0]
    code = args[1]
    workspace = args[2]
    sp.__spider_eval code, {workspace: workspace}
    sp.__save_buffer(buffer_id, code)
  rescue Exception => e
    puts "Caught exception when attempting to save and run buffer!"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/save-buffer") do |payload|
  begin
#    puts "Received save-buffer: #{payload.to_a}"
    args = payload.to_a
    buffer_id = args[0]
    code = args[1]
    sp.__save_buffer(buffer_id, code)
  rescue Exception => e
    puts "Caught exception when attempting to save buffer!"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/exit") do |payload|
#  puts "exiting..."
  begin
    sp.__exit
  rescue Exception => e
    puts "Received Exception when attempting to exit!"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/stop-all-jobs") do |payload|
#  puts "stopping all jobs..."
  begin
    sp.__stop_jobs
  rescue Exception => e
    puts "Received Exception when attempting to stop all jobs!"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/load-buffer") do |payload|
#  puts "loading buffer..."
  begin
    sp.__load_buffer(payload.to_a[0])
  rescue Exception => e
    puts "Received Exception when attempting to load buffer!"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/beautify-buffer") do |payload|
#  puts "beautifying buffer..."
  begin
    args = payload.to_a
    id = args[0]
    buf = args[1]
    sp.__beautify_buffer(id, buf)
  rescue Exception => e
    puts "Received Exception when attempting to load buffer!"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/ping") do |payload|
  #  puts "ping!"
  begin
    id = payload.to_a[0]
    m = encoder.encode_single_message("/ack", [id])
    gui.send_raw(m)
  rescue Exception => e
    puts "Received Exception when attempting to send ack!"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/start-recording") do |payload|
  begin
    sp.recording_start
  rescue Exception => e
    puts "Received Exception when attempting to start recording"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/stop-recording") do |payload|
  begin
    sp.recording_stop
  rescue Exception => e
    puts "Received Exception when attempting to stop recording"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/delete-recording") do |payload|
  begin
    sp.recording_delete
  rescue Exception => e
    puts "Received Exception when attempting to delete recording"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/save-recording") do |payload|
  begin
    filename = payload.to_a[0]
    sp.recording_save(filename)
  rescue Exception => e
    puts "Received Exception when attempting to delete recording"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/reload") do |payload|
  begin
    dir = File.dirname("#{File.absolute_path(__FILE__)}")
    Dir["#{dir}/../sonicpi/**/*.rb"].each do |d|
      load d
    end
    puts "reloaded"
  rescue Exception => e
    puts "Received Exception when attempting to reload files"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/mixer-invert-stereo") do |payload|
  begin
    sp.set_mixer_invert_stereo!
  rescue Exception => e
    puts "Received Exception when attempting to invert stereo"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/mixer-standard-stereo") do |payload|
  begin sp.set_mixer_standard_stereo!
  rescue Exception => e
    puts "Received Exception when attempting to set stereo to standard mode"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/mixer-stereo-mode") do |payload|
  begin
    sp.set_mixer_stereo_mode!
  rescue Exception => e
    puts "Received Exception when attempting to invert stereo"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/mixer-mono-mode") do |payload|
  begin sp.set_mixer_mono_mode!
  rescue Exception => e
    puts "Received Exception when attempting to switch to mono mode"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/mixer-hpf-enable") do |payload|
  begin
    freq = payload.to_a[0].to_f
    sp.set_mixer_hpf!(freq)
  rescue Exception => e
    puts "Received Exception when attempting to enable mixer hpf"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/mixer-hpf-disable") do |payload|
  begin
    sp.set_mixer_hpf_disable!
  rescue Exception => e
    puts "Received Exception when attempting to disable mixer hpf"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/mixer-lpf-enable") do |payload|
  begin
    freq = payload.to_a[0].to_f
    sp.set_mixer_lpf!(freq)
  rescue Exception => e
    puts "Received Exception when attempting to enable mixer lpf"
    puts e.message
    puts e.backtrace.inspect
  end
end

osc_server.add_method("/mixer-lpf-disable") do |payload|
  begin
    sp.set_mixer_lpf_disable!
  rescue Exception => e
    puts "Received Exception when attempting to disable mixer lpf"
    puts e.message
    puts e.backtrace.inspect
  end
end

Thread.new{osc_server.run}

# Send stuff out from Sonic Pi back out to osc_server
out_t = Thread.new do
  continue = true
  while continue
    begin
      message = ws_out.pop
      # message[:ts] = Time.now.strftime("%H:%M:%S")

      if message[:type] == :exit
        m = encoder.encode_single_message("/exited")
        gui.send_raw(m)
        continue = false
      else
        case message[:type]
        when :multi_message
          m = encoder.encode_single_message("/multi_message", [message[:jobid], message[:thread_name].to_s, message[:runtime].to_s, message[:val].size, *message[:val].flatten])
          gui.send_raw(m)
        when :info
          m = encoder.encode_single_message("/info", [message[:val]])
          gui.send_raw(m)
        when :error
          desc = message[:val] || ""
          trace = message[:backtrace].join("\n")
          # TODO: Move this escaping to the Qt Client
          desc = CGI.escapeHTML(desc)
          trace = CGI.escapeHTML(trace)
          # puts "sending: /error #{desc}, #{trace}"
          m = encoder.encode_single_message("/error", [message[:jobid], desc, trace])
          gui.send_raw(m)
        when "replace-buffer"
          buf_id = message[:buffer_id]
          content = message[:val]
#          puts "replacing buffer #{buf_id}, #{content}"
          m = encoder.encode_single_message("/replace-buffer", [buf_id, content])
          gui.send_raw(m)
        else
#          puts "ignoring #{message}"
        end

      end
    rescue Exception => e
      puts "Exception!"
      puts e.message
      puts e.backtrace.inspect
    end
  end
end

out_t.join
