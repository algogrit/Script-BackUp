#!/usr/bin/env ruby

require "fileutils"
require "json"
require "open3"
require "pathname"

cwd = File.expand_path(ARGV.first || Dir.pwd)

RESET = "\e[0m"
RED = "\e[31m"
GREEN = "\e[32m"
YELLOW = "\e[33m"
BLUE = "\e[34m"
CYAN = "\e[36m"

def find_password_file(base_dir)
  current_dir = base_dir

  loop do
    candidate = File.join(current_dir, "file_passwords.json")
    return candidate if File.exist?(candidate)

    parent_dir = File.dirname(current_dir)
    break if parent_dir == current_dir

    current_dir = parent_dir
  end

  nil
end

password_file = find_password_file(cwd)

def colorize(text, color)
  "#{color}#{text}#{RESET}"
end

def list_pdfs_recursively(wd)
  Dir.glob(File.join(wd, "**", "*.{pdf,PDF}"))
end

def get_password(pdf, pdf_unlock_map)
  pdf_unlock_map
    .sort_by { |key, _password| [-key.split("/").length, -key.length] }
    .each do |key, password|
      return password if pdf.include?(key)
    end

  nil
end

def relative_pdf_path(pdf, base_dir)
  Pathname.new(pdf).relative_path_from(Pathname.new(base_dir)).to_s
end

def needs_password?(pdf)
  stdout, stderr, status = Open3.capture3("qpdf", "--show-encryption", pdf)
  output = [stdout, stderr].reject(&:empty?).join("\n").strip
  encrypted = output.include?("File is encrypted") || output.include?("Incorrect password supplied") || output.match?(/\bR = \d+\b/)
  not_encrypted = output.include?("File is not encrypted")

  {
    requires_password: encrypted,
    no_password_required: not_encrypted,
    success_with_warnings: status.exitstatus == 3,
    exit_code: status.exitstatus,
    output: output,
    stdout: stdout,
    stderr: stderr,
  }
end

def load_password_map(password_file)
  JSON.parse(File.read(password_file))
end

def map_to_password(pdfs, pdf_unlock_map, base_dir)
  pdfs_with_passwords = {}
  unmatched_pdfs = []
  stats = {
    scanned: pdfs.length,
    encrypted: 0,
    check_warnings: 0,
    undetermined: 0,
    unmatched: 0,
  }

  pdfs.each do |pdf|
    relative_pdf = relative_pdf_path(pdf, base_dir)
    password_check = needs_password?(pdf)

    if password_check[:success_with_warnings]
      stats[:check_warnings] += 1
      warning_message = password_check[:output].to_s.strip
      puts colorize("Checked #{pdf} with qpdf warnings: #{warning_message}", YELLOW)
    end

    next if password_check[:no_password_required]

    unless password_check[:requires_password]
      stats[:undetermined] += 1
      puts colorize("Unable to determine encryption status for #{pdf}: #{password_check[:output]}", RED)
      next
    end

    stats[:encrypted] += 1
    password = get_password(relative_pdf, pdf_unlock_map)

    if password
      pdfs_with_passwords[pdf] = password
    else
      stats[:unmatched] += 1
      unmatched_pdfs << relative_pdf
    end
  end

  {
    pdfs_with_passwords: pdfs_with_passwords,
    unmatched_pdfs: unmatched_pdfs,
    stats: stats,
  }
end

def create_path(path)
  FileUtils.mkdir_p(path)
end

def decrypt_pdf(current_path, new_path, password)
  stdout, stderr, status = Open3.capture3(
    "qpdf",
    "--password=#{password}",
    "--decrypt",
    current_path,
    new_path
  )

  {
    success: status.success?,
    success_with_warnings: status.exitstatus == 3,
    exit_code: status.exitstatus,
    stdout: stdout,
    stderr: stderr,
  }
end

def unlock_pdf(pdf, password, base_dir)
  relative_pdf = relative_pdf_path(pdf, base_dir)
  pdf_name = File.basename(pdf)
  sub_path = File.dirname(relative_pdf)
  new_path = File.join("/tmp/unlocked-pdf", sub_path)

  create_path(new_path)

  new_pdf_path = File.join(new_path, pdf_name)

  puts "Unlocking #{pdf}..."
  decrypt_result = decrypt_pdf(pdf, new_pdf_path, password)

  if (decrypt_result[:success] || decrypt_result[:success_with_warnings]) && File.exist?(new_pdf_path)
    FileUtils.mv(new_pdf_path, pdf)

    if decrypt_result[:success_with_warnings]
      warning_message = decrypt_result[:stderr].to_s.strip
      warning_message = decrypt_result[:stdout].to_s.strip if warning_message.empty?
      puts colorize("Unlocked #{pdf} with qpdf warnings: #{warning_message}", YELLOW)
      return :warning
    end

    puts colorize("Unlocked #{pdf}", GREEN)
    return :success
  else
    error_message = decrypt_result[:stderr].to_s.strip
    error_message = decrypt_result[:stdout].to_s.strip if error_message.empty?
    error_message = "qpdf exited with code #{decrypt_result[:exit_code]}" if error_message.empty?

    puts colorize("Unable to decrypt #{pdf}: #{error_message} ... password: #{password}", RED)
    return :failed
  end
end

def unlock_pdfs(pdfs_with_passwords, base_dir)
  stats = {
    unlocked: 0,
    unlocked_with_warnings: 0,
    failed: 0,
  }

  pdfs_with_passwords.each do |pdf, password|
    result = unlock_pdf(pdf, password, base_dir)

    case result
    when :success
      stats[:unlocked] += 1
    when :warning
      stats[:unlocked_with_warnings] += 1
    else
      stats[:failed] += 1
    end
  end

  stats
end

def report_unmatched_pdfs(unmatched_pdfs)
  return if unmatched_pdfs.empty?

  puts colorize("Encrypted PDFs with no matching password rule:", YELLOW)
  unmatched_pdfs.sort.each do |pdf|
    puts colorize("- #{pdf}", YELLOW)
  end
end

def report_summary(scan_stats, unlock_stats)
  puts colorize("Summary:", CYAN)
  puts colorize("- scanned: #{scan_stats[:scanned]}", BLUE)
  puts colorize("- encrypted: #{scan_stats[:encrypted]}", BLUE)
  puts colorize("- unlocked: #{unlock_stats[:unlocked]}", GREEN)
  puts colorize("- unlocked_with_warnings: #{unlock_stats[:unlocked_with_warnings]}", YELLOW)
  puts colorize("- unmatched: #{scan_stats[:unmatched]}", YELLOW)
  puts colorize("- failed: #{unlock_stats[:failed]}", RED)
  puts colorize("- undetermined: #{scan_stats[:undetermined]}", RED)
  puts colorize("- check_warnings: #{scan_stats[:check_warnings]}", YELLOW)
end

abort("Missing password config: file_passwords.json not found in #{cwd} or its parent directories") unless password_file

pdf_unlock_map = load_password_map(password_file)
pdfs = list_pdfs_recursively(cwd)
mapping_result = map_to_password(pdfs, pdf_unlock_map, cwd)
report_unmatched_pdfs(mapping_result[:unmatched_pdfs])
unlock_stats = unlock_pdfs(mapping_result[:pdfs_with_passwords], cwd)
report_summary(mapping_result[:stats], unlock_stats)
