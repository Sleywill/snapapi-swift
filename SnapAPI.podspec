Pod::Spec.new do |s|
  s.name             = 'SnapAPI'
  s.version          = '3.2.0'
  s.summary          = 'Official Swift SDK for SnapAPI.pics -- screenshot, scrape, extract, PDF, video as a service.'
  s.description      = <<-DESC
    SnapAPI is a production-quality Swift SDK for the SnapAPI.pics REST API.
    It provides async/await methods for capturing screenshots, generating PDFs,
    scraping web content, extracting structured data, recording videos, and more.
    Built as an actor for thread safety, with exponential backoff retry logic,
    typed error handling, and zero third-party dependencies.
  DESC

  s.homepage         = 'https://github.com/Sleywill/snapapi-swift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'SnapAPI Team' => 'hello@snapapi.pics' }
  s.source           = { :git => 'https://github.com/Sleywill/snapapi-swift.git', :tag => s.version.to_s }

  s.swift_version    = '5.9'
  s.ios.deployment_target     = '15.0'
  s.osx.deployment_target     = '12.0'
  s.tvos.deployment_target    = '15.0'
  s.watchos.deployment_target = '8.0'

  s.source_files = 'Sources/SnapAPI/**/*.swift'
  s.frameworks   = 'Foundation'
end
