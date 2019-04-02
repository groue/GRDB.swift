use_frameworks!
workspace 'GRDB.xcworkspace'

def sql_cipher
  project 'GRDBCipher.xcodeproj'
  pod 'SQLCipher', '~> 4.1'
end

target 'GRDBCipherOSX' do
  platform :macos, '10.9'
  sql_cipher
end

target 'GRDBCipherOSXTests' do
  platform :macos, '10.9'
  sql_cipher
end

target 'GRDBCipherOSXEncryptedTests' do
  platform :macos, '10.9'
  sql_cipher
end

target 'GRDBCipheriOS' do
  platform :ios, '9.0'
  sql_cipher
end

target 'GRDBCipheriOSTests' do
  platform :ios, '9.0'
  sql_cipher
end

target 'GRDBCipheriOSEncryptedTests' do
  platform :ios, '9.0'
  sql_cipher
end
