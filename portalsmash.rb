#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'yaml'
require 'trollop'

#State Machine

# States:
#   Start - we know nothing.
#   List - We have the scanned list, written to a file.
#   Attached - We've gotten an attached note from WPA_CLI.
#   HasIP - We have an IP address from dhclient.
#   Breaker - We're running the breaker.
#   Monitor - Connection is solid, we'll periodically check it.

# State, Transition, New State

# Start, ScanSuccess, List
# Start, ScanFail, Start
# List, AttachSuccess, Attached
# List, AttachFail, List
# Attached, DHCPSuccess, HasIP
# Attached, DHCPFail, List
# HasIP, CCSuccess, Monitor
# HasIP, CCFail, Breaker
# Breaker, CCSuccess, Monitor
# Breaker, CCFail, List
# Monitor, CCSuccess, Monitor
# Monitor, CCFail, Start

class PortalSmasher
  
  #Variables for seeing what it's doing right now - not modifiable outside the class
  attr_reader :state, :running, :scan_success, :attach_state, :dhcp_success, :cc_success
  
  TESTPAGE = 'http://www.apple.com/library/test/success.html'
  CONFPATH = '/tmp/portalsmash.conf'
  
  ATTACH_SUCCESS = 0
  ATTACH_FAIL = 1
  ATTACH_OUT = 2
  
  def initialize(dev, file)
    @state = :start
    @running = true
    
    #Storage variables internal to the class (No accessors)
    @device = dev
    @list_count = 0
    @page = nil
    @agent = Mechanize.new
    @knownnetworks = {}
    
    if file
      @knownnetworks = YAML.load_file(file)
    end
  end
  
  def stop
    @running = false
  end
  
  def scan
    puts "Scanning"
    
    File.open(CONFPATH, "w") do |f|
      f.puts "ctrl_interface=DIR=/var/run/wpa_supplicant"
    
      networklist = `iwlist #{@device} scan`;
      networks = networklist.split(/Cell \d{2}/); #This will give us cell 1 in @networks[1], as [0] will hold junk
      networks.delete_at(0)
    
      usednetworks = {}
      
      networks.each do |net|
        data = net.split(/\n/)
        bssid = data[0].match(/([A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2})/)[1]
        ssid = data[5].match(/ESSID\:\"(.*)\"/)[1]
        enc = data[4].match(/Encryption key:(.+)/)[1]
        
        #So, only proceed if either we know the network, or if there's no encryption -- and either way, only
        #if we haven't done this network before (to prevent trying to connect to 80 different instances of
        #the same WiFi network)7888888
        if (!usednetworks[ssid] and ((enc == "off") or (@knownnetworks[ssid])))
          f.puts "network={"
          f.puts "ssid=\"#{ssid}\""
          f.puts "scan_ssid=1"
          if (enc == "on")
            # This is just a brutal hack. I can be a lot more precise-- specifying CCMP and the like-- but it doesn't matter, weirdly.
            
            if net =~ /WPA/
              if (@knownnetworks[ssid]['key']) #Then it's WPA-PSK
                f.puts "key_mgmt=WPA-PSK"
                f.puts "psk=\"#{@knownnetworks[ssid]['key']}\""
              else #Then it's WPAE
                f.puts "key_mgmt=WPA-EAP"
                f.puts "identity=\"#{@knownnetworks[ssid]['username']}\""
                f.puts "password=\"#{@knownnetworks[ssid]['password']}\""
              end
            else #WEP
              f.puts "key_mgmt=NONE"
              f.puts "wep_tx_keyidx=0"
              f.puts "wep_key0=\"#{@knownnetworks[ssid]['key']}\""
            end
            
          else
            f.puts "key_mgmt=NONE"
          end
          f.puts "}"
          f.puts ""
        end
        
        usednetworks[ssid] = 1
        
      end

    end
    
    exit(0)
  end
  
  def attach
    puts "Attaching"
    @attach_state = [ATTACH_SUCCESS, ATTACH_FAIL, ATTACH_FAIL, ATTACH_OUT].sample
  end
  
  def dhcp
    puts "DCHP-ing"
    @dhcp_success = [true, true, false].sample
  end
  
  def conncheck
    puts "Checking Connection"
    @page = @agent.get(TESTPAGE)
    if (@page.title == "Success") #Could add other checks here.
      @cc_success = true
    else
      @cc_success = false
    end
  end
  
  def runbreak
    puts "Portal Breaking"
    if (@page.forms.size == 1 && @page.forms[0].buttons.size == 1)
      f = @page.forms[0]
      f.submit(f.buttons[0])
    elsif (@page.forms.size == 1 && @page.forms[0].buttons.size == 0)
      p2 = @page.forms[0].submit
      if (p2.forms[0].buttons.size == 1)
        #WanderingWifi
        #This is sick, but truthfully this works. Shocking.
        f2 = p2.forms[0]
        p3 = f2.submit(f2.buttons[0])
        p4 = p3.forms[0].submit
        p5 = p4.forms[0].submit
        p6 = p5.forms[0].submit
        p7 = p6.forms[0].submit
        p8 = agent.get('http://portals.wanderingwifi.com:8080/session.asp')
      end
    end
  end

  
  def run
    while @running
      #sleep 1
      puts ""
      puts "State: #{@state}"
      case @state
      when :start
        scan
        if @scan_success
          @state = :list
        else
          @state = :start
        end
      when :list
        attach
        case @attach_state
        when ATTACH_SUCCESS
          @state = :attached
        when ATTACH_FAIL
          @state = :list
        when ATTACH_OUT
          @state = :start
        end
      when :attached
        dhcp
        if @dhcp_success
          @state = :hasip
        else
          @state = :attached
        end
      when :hasip
        conncheck
        if @cc_success
          @state = :monitor
        else
          @state = :breaker
        end
      when :breaker
        runbreak
        conncheck
        if @cc_success
          @state = :monitor
        else
          @state = :list
        end
      when :monitor
        sleep 2
        conncheck
        if @cc_success
          @state = :monitor
        else
          @state = :start
        end
      end
    end
  end
end

opts = Trollop::options do
  version "Version 0.01, (c) 2013 Malice Afterthought, Inc."
  banner <<-HEREBEDRAGONS
  
PortalSmash is a program that gets you through "captive portals" and other
annoyances. It connects to any open WiFi and attempts to get an IP and make
sure it works. If it works, it keeps rechecking every few seconds, 
reconnecting (or finding a new connection) if it drops.

Netfile format:
PortalSmash allows a network key file to be specified that includes, well, keys
for networks. The file must be in YAML, and formatted approximately as so:
  
---
NetName:
	key: ohboyitsakey 
HypotheticalWPAE:
	username: foo
	password: bar

This will allow the program to connect to WiFi for which you have been given
credentials (e.g., your home WiFi network).

Usage:
  portalsmash [options]
where [options] are:

HEREBEDRAGONS
  
  opt :device, "Device to connect", :type => :string, :default => "wlan0" # string --name <device>, default to wlan0
  opt :netfile, "Network key file in YAML format, as detailed above", :type => :io #io --netfile <path>
end



ps = PortalSmasher.new(opts[:device], opts[:netfile])
ps.run

