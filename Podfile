use_frameworks!
workspace 'GRDB.xcworkspace'
project 'GRDBCipher.xcodeproj'

def sql_cipher
  pod 'SQLCipher', '~> 4.1'
end

target 'GRDBOSX' do
  platform :macos, '10.9'
  sql_cipher
end

target 'GRDBOSXTests' do
  platform :macos, '10.9'
  sql_cipher
end

target 'GRDBOSXEncryptedTests' do
  platform :macos, '10.9'
  sql_cipher
end

target 'GRDBiOS' do
  platform :ios, '9.0'
  sql_cipher
end

target 'GRDBiOSTests' do
  platform :ios, '9.0'
  sql_cipher
end

target 'GRDBiOSEncryptedTests' do
  platform :ios, '9.0'
  sql_cipher
end
