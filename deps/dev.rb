dep 'build tools' do
  requires {
    on :osx, 'xcode tools'
    on :snow_leopard, 'llvm in path'
    on :linux, 'build-essential', dep('autoconf.managed'), dep('automake.managed'), dep('libtool.managed')
  }
end

dep 'build-essential', :template => 'managed' do
  provides 'gcc', 'g++', 'make', 'ld'
end
