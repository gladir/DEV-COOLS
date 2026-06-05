path = "sample_out.txt"

File.write(path, "line 1\nline 2\n")
puts File.exist?(path)
puts File.read(path)
File.delete(path)
