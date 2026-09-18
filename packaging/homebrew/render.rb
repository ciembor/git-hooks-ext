require "digest"
require "erb"
require "uri"

archive, version, template, destination = ARGV
abort "usage: render.rb ARCHIVE VERSION TEMPLATE DESTINATION" unless ARGV.length == 4
archive_path = URI::DEFAULT_PARSER.escape(File.expand_path(archive), /[^A-Za-z0-9._~\/-]/)
source_url = URI::Generic.build(scheme: "file", host: "", path: archive_path).to_s
checksum = Digest::SHA256.file(archive).hexdigest
content = ERB.new(File.read(template)).result_with_hash(
  source_url: source_url, version: version, checksum: checksum
)
File.write(destination, content)
