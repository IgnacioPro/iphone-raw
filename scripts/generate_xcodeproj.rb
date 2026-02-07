#!/usr/bin/env ruby

require "fileutils"

begin
  require "xcodeproj"
rescue LoadError
  warn "Missing gem 'xcodeproj'. Install with: gem install xcodeproj"
  exit 1
end

ROOT = File.expand_path("..", __dir__)
IOS_DIR = File.join(ROOT, "ios")
APP_DIR = File.join(IOS_DIR, "PhotodewApp")
PROJECT_PATH = File.join(IOS_DIR, "PhotodewApp.xcodeproj")
SCHEME_NAME = "PhotodewApp"
LOCAL_PACKAGE_RELATIVE_PATH = ".."
MIN_IOS_VERSION = "17.0"

FileUtils.mkdir_p(APP_DIR)
FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastUpgradeCheck"] = "1620"

app_group = project.main_group.new_group("PhotodewApp", "PhotodewApp")

target = project.new_target(:application, SCHEME_NAME, :ios, MIN_IOS_VERSION)
target.product_name = SCHEME_NAME

# Remove default Foundation.framework reference created by xcodeproj template.
target.frameworks_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref&.path&.end_with?("Foundation.framework")

  build_file.remove_from_project
  file_ref.remove_from_project
end

source_refs = %w[
  ContentView.swift
  PhotodewIOSApp.swift
].map do |file_name|
  app_group.new_file(file_name)
end

target.add_file_references(source_refs)

target.build_configurations.each do |config|
  settings = config.build_settings
  settings.delete("ASSETCATALOG_COMPILER_APPICON_NAME")
  settings.delete("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME")
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.photodew.app"
  settings["IPHONEOS_DEPLOYMENT_TARGET"] = MIN_IOS_VERSION
  settings["SWIFT_VERSION"] = "6.0"
  settings["CODE_SIGN_STYLE"] = "Automatic"
  settings["DEVELOPMENT_TEAM"] = ""
  settings["TARGETED_DEVICE_FAMILY"] = "1,2"
  settings["GENERATE_INFOPLIST_FILE"] = "YES"
  settings["INFOPLIST_KEY_NSCameraUsageDescription"] = "Photodew needs camera access to capture photos."
  settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
end

package_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package_ref.relative_path = LOCAL_PACKAGE_RELATIVE_PATH
project.root_object.package_references << package_ref

def add_local_package_product(project, target, package_ref, product_name)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package_ref
  dependency.product_name = product_name
  target.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

%w[App CaptureUI].each do |product_name|
  add_local_package_product(project, target, package_ref, product_name)
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, nil)
scheme.launch_action.buildable_product_runnable = Xcodeproj::XCScheme::BuildableProductRunnable.new(target)
scheme.launch_action.add_macro_expansion(Xcodeproj::XCScheme::MacroExpansion.new(target))
scheme.profile_action.buildable_product_runnable = Xcodeproj::XCScheme::BuildableProductRunnable.new(target)
scheme.test_action.add_macro_expansion(Xcodeproj::XCScheme::MacroExpansion.new(target))
scheme.save_as(PROJECT_PATH, SCHEME_NAME, true)

puts "Generated #{PROJECT_PATH}"
