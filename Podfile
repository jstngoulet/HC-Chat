# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

source 'https://github.com/CocoaPods/Specs.git'
source 'git@gitlab.com:hyrecar-dev/iOS/podspecs.git'

target 'HC-Chat' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for HC-Chat
  pod 'HC-Chat', :path => "./"
  pod 'SendBirdSDK'
  pod 'RxSwift'
  pod 'RxCocoa'

  target 'HC-ChatTests' do
    inherit! :search_paths
    # Pods for testing
  end

end
