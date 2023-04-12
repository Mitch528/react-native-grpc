require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-grpc"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "10.0" }
  s.source       = { :git => "https://github.com/krishnafkh/react-native-grpc.git", :tag => "#{s.version}" }


  s.source_files = "ios/**/*.{h,m,mm,swift}"


  s.dependency "React-Core"
  s.dependency "gRPC"

  # Pods directory corresponding to this app's Podfile, relative to the location of this podspec.
  pods_root = 'Pods'

  s.pod_target_xcconfig = {
    # This is needed by all pods that depend on gRPC-RxLibrary:
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
  }
end