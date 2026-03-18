#!/usr/bin/env ruby

require "fileutils"
require "xcodeproj"

PROJECT_NAME = "ClipMoar"
PROJECT_PATH = "#{PROJECT_NAME}.xcodeproj"
APP_BUNDLE_ID = "com.noma4i.ClipMoar"
TEST_BUNDLE_ID = "com.noma4i.ClipMoarTests"
DEPLOYMENT_TARGET = "14.0"

def configure_build_settings(target, bundle_id:, plist: nil, entitlements: nil, is_app: false, is_test: false)
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
    settings["SWIFT_VERSION"] = "5.9"
    settings["MACOSX_DEPLOYMENT_TARGET"] = DEPLOYMENT_TARGET
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
    settings["ENABLE_TESTABILITY"] = "YES" if config.name == "Debug"
    settings["SWIFT_EMIT_LOC_STRINGS"] = "YES"
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["DEVELOPMENT_TEAM"] = ""

    if plist
      settings["GENERATE_INFOPLIST_FILE"] = "NO"
      settings["INFOPLIST_FILE"] = plist
    else
      settings["GENERATE_INFOPLIST_FILE"] = "YES"
    end

    settings["CODE_SIGN_ENTITLEMENTS"] = entitlements if entitlements

    if is_app
      settings["ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS"] = "NO"
      settings["LD_RUNPATH_SEARCH_PATHS"] = ["$(inherited)", "@executable_path/../Frameworks"]
      settings["DEFINES_MODULE"] = "YES"
      settings["ENABLE_HARDENED_RUNTIME"] = "NO"
      settings["SWIFT_OBJC_BRIDGING_HEADER"] = ""
    end

    next unless is_test

    settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/#{PROJECT_NAME}.app/Contents/MacOS/#{PROJECT_NAME}"
    settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
    settings["LD_RUNPATH_SEARCH_PATHS"] = [
      "$(inherited)",
      "@executable_path/../Frameworks",
      "@loader_path/../Frameworks",
    ]
  end
end

def add_file(groups_root, relative_path)
  parts = relative_path.split("/")
  file_name = parts.pop
  group = parts.reduce(groups_root) do |current, part|
    current.find_subpath(part, true)
  end
  group.new_file(relative_path)
end

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastUpgradeCheck"] = "2630"
project.root_object.attributes["TargetAttributes"] = {}

app_target = project.new_target(:application, PROJECT_NAME, :osx, DEPLOYMENT_TARGET)
test_target = project.new_target(:unit_test_bundle, "#{PROJECT_NAME}Tests", :osx, DEPLOYMENT_TARGET)
test_target.add_dependency(app_target)

configure_build_settings(
  app_target,
  bundle_id: APP_BUNDLE_ID,
  plist: "ClipMoar/Resources/Info.plist",
  entitlements: "ClipMoar/Resources/ClipMoar.entitlements",
  is_app: true
)

configure_build_settings(
  test_target,
  bundle_id: TEST_BUNDLE_ID,
  is_test: true
)

main_group = project.main_group
main_group.set_source_tree("<group>")

clipmoar_group = main_group.find_subpath("ClipMoar", true)
tests_group = main_group.find_subpath("Tests", true)
scripts_group = main_group.find_subpath("scripts", true)

swift_sources = Dir.glob("ClipMoar/**/*.swift").sort
test_sources = Dir.glob("Tests/**/*.swift").sort
resource_files = Dir.glob("assets/*").sort + ["LICENSE"]
support_files = [
  "ClipMoar/Resources/Info.plist",
  "ClipMoar/Resources/ClipMoar.entitlements",
  "Package.swift",
  "README.md",
]

swift_sources.each do |path|
  ref = add_file(main_group, path)
  app_target.source_build_phase.add_file_reference(ref)
end

test_sources.each do |path|
  ref = add_file(main_group, path)
  test_target.source_build_phase.add_file_reference(ref)
end

resource_files.each do |path|
  ref = add_file(main_group, path)
  app_target.resources_build_phase.add_file_reference(ref)
end

(support_files + ["scripts/build.sh", "scripts/release.sh", "scripts/run.sh", "scripts/lint.sh", "scripts/clean.sh", "scripts/generate_xcodeproj.rb"]).each do |path|
  add_file(main_group, path)
end

project.products_group.set_source_tree("<group>")

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.add_test_target(test_target)
scheme.set_launch_target(app_target)
scheme.save_as(PROJECT_PATH, PROJECT_NAME, true)

project.save
