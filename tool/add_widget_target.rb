#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the OutaboutWidget WidgetKit extension to ios/Runner.xcodeproj.
#
# Why a script rather than a committed pbxproj edit: project.pbxproj is a
# UUID-keyed graph, and an extension target touches nine parts of it — the
# target, three build configurations plus their config list, the file
# references and group, the sources and resources phases, the product
# reference, a target dependency on Runner, and an Embed Foundation Extensions
# phase on Runner in a position that matters. Hand-writing that is possible and
# unreviewable. This is re-runnable, so the project can be regenerated after a
# `flutter create` overwrite or a bad merge.
#
# Idempotent: every step checks for its own output first, so a second run is a
# no-op that prints what it found.
#
# Run with CocoaPods' vendored xcodeproj, which is already on this machine:
#
#   GEM_HOME=/opt/homebrew/Cellar/cocoapods/<version>/libexec \
#     ruby tool/add_widget_target.rb
#
# or just `tool/add_widget_target.sh`, which works that path out.

require 'xcodeproj'

PROJECT_PATH  = File.expand_path('../ios/Runner.xcodeproj', __dir__)
TARGET_NAME   = 'OutaboutWidget'
APP_TARGET    = 'Runner'
BUNDLE_ID     = 'com.outabout.outabout.OutaboutWidget'
GROUP_DIR     = 'OutaboutWidget'
# WidgetKit needs 14, containerBackground needs 17. The app stays on 13.0 —
# an extension may sit above its host.
DEPLOYMENT    = '17.0'

SOURCES   = %w[OutaboutWidget.swift WidgetPayload.swift].freeze
RESOURCES = %w[PrivacyInfo.xcprivacy].freeze

# The host app's floor, raised from 13.0. Forced, not chosen: the home_widget
# pod refuses to install below 14.0, and `pod install` fails outright rather
# than warning. Nothing is lost — WidgetKit itself needs 14 and this widget
# needs 17, so no device that could have shown the widget is affected. It only
# changes which devices can run the app at all, and iOS 13 predates every
# other minimum in this project.
APP_DEPLOYMENT = '14.0'

project = Xcodeproj::Project.open(PROJECT_PATH)
app = project.targets.find { |t| t.name == APP_TARGET }
abort "Could not find the #{APP_TARGET} target" if app.nil?

changed = false

# --- host app deployment target ------------------------------------------
project.build_configurations.each do |config|
  current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
  next if current == APP_DEPLOYMENT

  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = APP_DEPLOYMENT
  puts "+ #{config.name}: iOS #{current} -> #{APP_DEPLOYMENT}"
  changed = true
end

# --- the extension target -------------------------------------------------
target = project.targets.find { |t| t.name == TARGET_NAME }
if target
  puts "= target #{TARGET_NAME} already present"
else
  target = project.new_target(
    :app_extension, TARGET_NAME, :ios, DEPLOYMENT, nil, :swift
  )
  puts "+ target #{TARGET_NAME}"
  changed = true
end

# --- base configuration ---------------------------------------------------
# Gives the extension FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER. Without a base
# configuration those are undefined, the two version keys in its Info.plist
# resolve to empty, Xcode omits them, and the built .appex fails to install
# with "Failed to create app extension placeholder" — an error that names
# neither the missing key nor the target. Verified the hard way.
# The existing Flutter group has no path of its own, so every child carries
# the full 'Flutter/...' prefix. A bare name here resolves to ios/ and the
# build fails with "Unable to open base configuration reference file".
flutter_group = project.main_group['Flutter'] ||
                project.main_group.new_group('Flutter', 'Flutter')
XCCONFIG_PATH = 'Flutter/Widget.xcconfig'

# Clean up a reference left by an earlier run of this script that used the
# wrong path, so re-running repairs the project instead of layering on it.
flutter_group.files
             .select { |f| f.path == 'Widget.xcconfig' }
             .each(&:remove_from_project)

widget_xcconfig = flutter_group.files.find { |f| f.path == XCCONFIG_PATH } ||
                  flutter_group.new_reference(XCCONFIG_PATH)

target.build_configurations.each do |config|
  next if config.base_configuration_reference == widget_xcconfig

  config.base_configuration_reference = widget_xcconfig
  puts "+ #{config.name}: base configuration Widget.xcconfig"
  changed = true
end

# --- build settings -------------------------------------------------------
# Written on every run, not just on creation: these are the settings most
# likely to be clobbered by an Xcode UI change, and re-asserting them is the
# point of being able to re-run this.
target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER']    = BUNDLE_ID
  s['PRODUCT_NAME']                 = '$(TARGET_NAME)'
  s['IPHONEOS_DEPLOYMENT_TARGET']   = DEPLOYMENT
  s['SWIFT_VERSION']                = '5.0'
  s['INFOPLIST_FILE']               = "#{GROUP_DIR}/Info.plist"
  s['CODE_SIGN_ENTITLEMENTS']       = "#{GROUP_DIR}/#{TARGET_NAME}.entitlements"
  s['GENERATE_INFOPLIST_FILE']      = 'NO'
  s['SKIP_INSTALL']                 = 'YES'
  s['TARGETED_DEVICE_FAMILY']       = '1'
  s['LD_RUNPATH_SEARCH_PATHS'] =
    ['$(inherited)', '@executable_path/Frameworks',
     '@executable_path/../../Frameworks']
end

# No signing overrides here, deliberately. Forcing ad-hoc simulator signing
# (CODE_SIGN_IDENTITY=-, CODE_SIGNING_ALLOWED=YES) was tried and does not work:
# the binary does become ad-hoc signed, but with no DEVELOPMENT_TEAM Xcode
# still emits an *empty* .xcent, because it will only embed entitlements it can
# justify against a provisioning profile. Both halves then fall back to a
# private plist — verified on this project, where OneSignal's own
# UserDefaults(suiteName:) landed in the app's private container rather than in
# Containers/Shared/AppGroup.
#
# So the App Group genuinely requires the Apple Developer account, and no build
# setting substitutes for it. Leaving the overrides in would have been settings
# that look like they do something and do not.

# --- Profile configuration ------------------------------------------------
# The Podfile declares Debug/Profile/Release. A target missing Profile breaks
# `flutter build ios --profile` and `flutter run --profile`, which is not
# something the simulator run would ever reveal.
unless target.build_configurations.map(&:name).include?('Profile')
  release = target.build_configurations.find { |c| c.name == 'Release' }
  profile = project.add_build_configuration('Profile', :release)
  target.build_configuration_list.build_configurations << profile
  profile.build_settings = release.build_settings.dup
  puts '+ Profile configuration'
  changed = true
end

# --- files ----------------------------------------------------------------
group = project.main_group[GROUP_DIR] || project.main_group.new_group(
  GROUP_DIR, GROUP_DIR
)

# `.map.compact` rather than `filter_map`: macOS system Ruby is 2.6.
existing = target.source_build_phase.files.map { |f| f.file_ref && f.file_ref.path }.compact
SOURCES.each do |name|
  next puts("= source #{name}") if existing.include?(name)

  ref = group.files.find { |f| f.path == name } || group.new_reference(name)
  target.add_file_references([ref])
  puts "+ source #{name}"
  changed = true
end

resource_paths =
  target.resources_build_phase.files.map { |f| f.file_ref && f.file_ref.path }.compact
RESOURCES.each do |name|
  next puts("= resource #{name}") if resource_paths.include?(name)

  ref = group.files.find { |f| f.path == name } || group.new_reference(name)
  target.add_resources([ref])
  puts "+ resource #{name}"
  changed = true
end

# Info.plist and the entitlements are referenced by build setting, not
# compiled, but they belong in the group so they are visible in Xcode.
%w[Info.plist OutaboutWidget.entitlements].each do |name|
  next if group.files.any? { |f| f.path == name }

  group.new_reference(name)
  puts "+ reference #{name}"
  changed = true
end

# --- embed into the app ---------------------------------------------------
unless app.dependencies.any? { |d| d.target == target }
  app.add_dependency(target)
  puts '+ Runner depends on the widget'
  changed = true
end

embed = app.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
if embed
  puts '= Embed Foundation Extensions phase already present'
else
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.dst_path = ''

  # Ordering is load bearing. `xcode_backend.sh embed_and_thin` (the "Thin
  # Binary" phase) and the two [CP] Pods phases operate on the finished app
  # wrapper, so the extension has to be inside it before they run. Xcode
  # appends new phases at the end, which is after all three.
  app.build_phases.delete(embed)
  thin = app.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
  app.build_phases.insert(thin || app.build_phases.length, embed)
  puts "+ Embed Foundation Extensions phase (before Thin Binary at #{thin})"
  changed = true
end

unless embed.files.any? { |f| f.display_name == "#{TARGET_NAME}.appex" }
  ref = embed.add_file_reference(target.product_reference)
  ref.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  puts '+ widget added to the embed phase'
  changed = true
end

if changed
  project.save
  puts "\nSaved #{PROJECT_PATH}"
else
  puts "\nNothing to do — project already has the widget target."
end
