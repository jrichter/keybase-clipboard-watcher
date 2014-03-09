#!/usr/bin/env ruby
require 'pty'
require 'expect'

PGP_HISTORY="#{ENV['HOME']}/.pgp-history"
TMP_FILE="#{ENV['HOME']}/tmp/.pgp-msg"
PASSWORD=File.read("#{ENV['HOME']}/.keybase-password") #This should be mod 650 to protect your password!
LIMIT=200

unless File.exist?(PGP_HISTORY)
  File.open(PGP_HISTORY, 'w') { |f| f.write('') }
end

msgs = File.read(PGP_HISTORY).split(/-----END PGP MESSAGE-----/).map {|m| "#{m}-----END PGP MESSAGE-----"} # Add back ending

loop do
  pgp_msg = `xclip -o -selection clipboard`
  if pgp_msg.split(/\n/).first == "-----BEGIN PGP MESSAGE-----" # Found a PGP MESSAGE in the clipboard
    decrypted = []
    if pgp_msg != msgs.first
      msgs = ([pgp_msg] + msgs).uniq[0...LIMIT]
      File.open(PGP_HISTORY, 'w') do |file|
        file.write(msgs.join("\n"))
      end
      `notify-send 'Incomming Encrypted Message!'`
      File.open(TMP_FILE,'w') { |f| f.write(pgp_msg)}
      PTY.spawn("keybase decrypt #{TMP_FILE}") do |r,w,pid|
        begin
          r.expect(/Enter passphrase:/) do |output|
            w.print PASSWORD
          end
          while line = r.gets
            break if line.scan(/info: Valid/) != []
            decrypted << line
          end
        rescue => e
          puts "An error occured #{e.inspect}"
        end
      end
      decrypted.each do |line|
        line = line.gsub(/\r\n/,"")
        timeout = line.length - 10
        if timeout < 0
          timeout = 5
        end
        unless line == ""
          `notify-send -t #{timeout} "Decrytped Message:" "#{line}"`
        end
      end
    else
      # puts "msg already processed"
    end
  else
    # puts "no pgp message found"
  end
  sleep 3
end
