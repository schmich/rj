require 'json'

def usage
  puts <<EOF
Usage: rj [OPTIONS] [script] 

Ruby JSON processor - https://github.com/schmich/rj

Options:
  -f, --file <filename>     Process JSON data from <filename> (default: stdin)
  -l, --lines
  -c, --combine-lines
  -s, --script <filename>   Use <filename> as script to process input
  -j, --output-json         Output compact JSON (default)
  -p, --output-pretty       Output pretty-printed JSON
  -r, --output-raw          Output raw
  -n, --output-none         Suppress default result output
  -v, --version             Show version
  -h, --help                Show this help
EOF
end

input = STDIN
output = :json
lines = false
combine_lines = false
script = 'j'
data_filename = nil
script_filename = nil

args = ARGV.clone
while args.any?
  arg = args.shift
  case arg.downcase
  when '--lines', '-l'
    raise '--lines is incompatible with --combine-lines' if combine_lines
    lines = true
  when '--combine-lines', '-c'
    raise '--combine-lines is incompatible with --lines' if lines
    combine_lines = true
  when '--output-pretty', '-p'
    output = :pretty
  when '--output-raw', '-r'
    output = :raw
  when '--output-json', '-j'
    output = :json
  when '--output-none', '-n'
    output = :none
  when '--file', '-f'
    data_filename = args.shift
    raise 'JSON filename is required.' if data_filename.nil?
  when '--script', '-s'
    script_filename = args.shift
    raise 'Script filename is required.' if script_filename.nil?
  when '--help', '-h'
    usage
    exit 1
  else
    script = arg
  end
end

def get_binding(j)
  binding
end

run_script = lambda { |json|
  # TODO: Support OpenStruct for .name access
  # TODO: Support :name symbol access

  result = eval(script, get_binding(json))

  case output
  when :raw
    puts result
  when :pretty
    puts JSON.pretty_generate(result)
  when :json
    puts JSON.dump(result)
  when :none
    # No output.
  end
}

if data_filename
  input = File.open(data_filename, 'r')
end

if script_filename
  script = File.read(script_filename)
end

if lines
  while input.readline
    json = JSON.load($_, nil, quirks_mode: true)
    run_script.call(json)
  end rescue EOFError
elsif combine_lines
  combined = []
  while input.readline
    combined << JSON.load($_, nil, quirks_mode: true)
  end rescue EOFError
  run_script.call(combined)
else
  json = JSON.load(input, nil, quirks_mode: true)
  run_script.call(json)
end
