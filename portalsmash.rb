require 'rubygems'
require 'mechanize'
require 'yaml'



def checkpage(page)
  if (page.title == "Success") #Could add other checks here.
    return true
  end
  return false
end

def breakout(page)
  #Break the portal, if we can.
  # Is there only one form? Does it have only one button? Click it.
  if (page.forms.size == 1 && page.forms[0].buttons.size == 1)
    f = page.forms[0]
    f.submit(f.buttons[0])
  elsif (page.forms.size == 1 && page.forms[0].buttons.size == 0)
    p2 = page.forms[0].submit
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

def something
  page = agent.get(testpage)
  while (!checkpage(page))
    breakout(page)
    page = agent.get(testpage)
  end
  puts "Connection is a success."
end


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
  
  def initialize
    @state = :start
    @running = true
    
    #Storage variables internal to the class (No accessors)
    @list_count = 0
    @page = nil
    @agent = Mechanize.new
  end
  
  def stop
    @running = false
  end
  
  def scan
    puts "Scanning"
    @scan_success = [true, true, true, false].sample
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


ps = PortalSmasher.new
ps.run

