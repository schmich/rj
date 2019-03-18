require 'fileutils'
require 'digest'

def run(command)
  puts command
  system(command)
end

package = 'traveling-ruby-20150210-2.1.5-win32.tar.gz'
ENV['PATH'] += ';C:\Program Files\7-Zip'

if !Dir.exist?('runtime')
  FileUtils.mkdir_p('runtime\lib\ruby')
  FileUtils.mkdir_p('runtime\lib\app')
  run("curl -L -O --fail \"https://d6r77u77i8pq3.cloudfront.net/releases/#{package}\"")
  run("7z x \"#{package}\" -so | 7z x -aoa -si -ttar -o\"runtime\\lib\\ruby\"")
  run("del \"#{package}\"")
end

run('copy /y main.rb runtime\lib\app\main.rb')
run('go-bindata -nometadata runtime/...')

version = `git tag`.lines.last.strip
commit = `git rev-parse HEAD`
payloadHash = Digest::SHA256.file('bindata.go').hexdigest[0...8]
run("go build -ldflags \"-w -s -X main.version=#{version} -X main.commit=#{commit} -X main.payloadDir=#{version}.#{payloadHash}\"")
