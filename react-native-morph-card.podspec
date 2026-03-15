require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

fabric_enabled = ENV['RCT_NEW_ARCH_ENABLED'] == '1'

Pod::Spec.new do |s|
  s.name         = 'react-native-morph-card'
  s.version      = package['version']
  s.summary      = package['description']
  s.homepage     = package['homepage']
  s.license      = package['license']
  s.authors      = package['author']
  s.platforms    = { :ios => '15.1', :tvos => '15.1', :visionos => '1.0' }
  s.source       = { :git => package['repository']['url'], :tag => "v#{s.version}" }

  s.source_files = 'ios/*.{h,m,mm}'

  if fabric_enabled
    install_modules_dependencies(s)

    s.subspec 'common' do |ss|
      ss.source_files = 'common/cpp/**/*.{cpp,h}'
      ss.header_dir = 'react/renderer/components/morphcard'
      ss.pod_target_xcconfig = {
        'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/common/cpp"',
      }
    end

    s.subspec 'fabric' do |ss|
      ss.dependency "#{s.name}/common"
      ss.source_files = 'ios/Fabric/**/*.{h,m,mm}'
      ss.pod_target_xcconfig = {
        'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/common/cpp"',
      }
    end
  else
    s.exclude_files = 'ios/Fabric/**'
    s.dependency 'React-Core'
  end
end
