#
# Cookbook Name:: openmeetings
# Recipe:: default
#
# Copyright 2012, Apache
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# enable multiverse
bash "enable multiverse" do
  code <<EOF
still=`egrep "^# deb .*multiverse" /etc/apt/sources.list`
echo "$still"
if [ -n "$still" ]; then
  sed -i "s/^# deb \\(.*\\) multiverse/deb \\1 multiverse/" /etc/apt/sources.list
  sed -i "s/^# deb-src \\(.*\\) multiverse/deb \\1 multiverse/" /etc/apt/sources.list
  still=`egrep "^# deb .*multiverse" /etc/apt/sources.list`
  [ -n "$still" ] && echo "Failed to enable multiverse" && exit 2
  apt-get update
fi
EOF
end

#
# could not find: libt-1.5 gs-gpl
%w{curl wget nano
  openoffice.org-writer openoffice.org-calc openoffice.org-impress openoffice.org-draw openoffice.org-math
  imagemagick
  libgif-dev xpdf libfreetype6 libfreetype6-dev libjpeg62 libjpeg8 libjpeg8-dev
  g++
  libjpeg-dev
  libdirectfb-dev
  libart-2.0-2 zip unzip bzip2 subversion git-core checkinstall yasm texi2html
  libfaac-dev libfaad-dev libmp3lame-dev libsdl1.2-dev libx11-dev libxfixes-dev libxvidcore-dev
  zlib1g-dev libogg-dev sox libvorbis0a libvorbis-dev libgsm1 libgsm1-dev libfaad2 flvtool2 lame
  }.each do |p|
  package p do
    action [:install]
  end

end

bash "swf tools from source" do
  code <<-CODE
curl -O http://www.swftools.org/swftools-2011-12-15-1229.tar.gz
tar -zvxf swftools-2011-12-15-1229.tar.gz
cd swftools-2011-12-15-1229
./configure --prefix=/usr/local
make
make install
CODE
  only_if do
    `pdf2swf -V | grep swftools | grep 2011-12-15-1229`.strip.empty?
  end
end

bash "ffmpeg from source" do
  code <<-CODE
rm -rf /tmp/ffmpeg_build
mkdir -p /tmp/ffmpeg_build
curl -O http://ffmpeg.org/releases/ffmpeg-0.9.1.tar.gz
tar zxf ffmpeg-0.9.1.tar.gz
cd ffmpeg-0.9.1
./configure --enable-libmp3lame --enable-libxvid --enable-libvorbis --enable-libgsm --enable-libfaac --enable-gpl --enable-nonfree
make
checkinstall
version_check=`ffmpeg -version | grep ffmpeg | grep 0.9.1`
if [ -z "$version_check" ]; then
  echo "Failed to install ffmpeg"
  exit 1
fi
CODE
  only_if do
    `ffmpeg -version | grep ffmpeg | grep 0.9.1`.strip.empty?
  end

end

include_recipe "ant"
bash "jod install" do
  code <<-CODE
rm -rf /usr/adm/jodconverter*
mkdir -p /usr/adm
cd /usr/adm
wget http://jodconverter.googlecode.com/files/jodconverter-core-3.0-beta-4-dist.zip
unzip jodconverter-core-3.0-beta-4-dist.zip
CODE
  not_if do
    ::File.exist? "/usr/adm/jodconverter-core-3.0-beta-4"
  end
end

subversion "openmeetings" do
  repository "https://svn.apache.org/repos/asf/incubator/openmeetings/trunk/singlewebapp/"
  revision "HEAD"
  destination "/usr/adm/singlewebapp"
  action :sync
end

# checkout the sources of openmeetings
# call ant.
# if successful, rename the dist folder into dist_ok
# so we don't go through ant+ivy again and again (useful at least for now
# more complex to rebuild when the sources change.).
bash "openmeetings build and install from source" do
  code <<-CODE
if [ -z "$JAVA_HOME" -o ! -f "$JAVA_HOME/bin/java" ]; then
  javac_loc=`which javac`
  echo "javac_loc: $javac_loc"
  export JAVA_HOME=$(readlink -f $javac_loc | sed "s:bin/javac::")
fi
echo "JAVA_HOME $JAVA_HOME"
cd /usr/adm/singlewebapp
ant -Ddb=mysql
if [ ! -d "dist/red5" ]; then
  echo "build failed: no "`pwd`" dist/red5"
  exit 1
fi
if [ ! -d "dist/red5/webapps/openmeetings" ]; then
  echo "build distfailed: no "`pwd`" dist/red5/webapps/openmeetings"
  exit 1
fi
mv dist dist_ok
CODE
  not_if do
    ::File.exist?("/usr/adm/singlewebapp/dist_ok")
  end
end

bash "install the built openmeetings" do
code <<-CODE
mv /usr/adm/singlewebapp/dist_ok/red5 /usr/lib/
cd /usr/lib/red5
cp -R /usr/adm/jodconverter-core-3.0-beta-4 webapps/openmeetings
chown -R nobody /usr/lib/red5
chmod +x /usr/lib/red5/red5.sh
chmod +x /usr/lib/red5/red5-debug.sh

[ ! -f "webapps/openmeetings/WEB-INF/classes/META-INF/persistence.xml-ori" ] && mv webapps/openmeetings/WEB-INF/classes/META-INF/persistence.xml webapps/openmeetings/WEB-INF/classes/META-INF/persistence.xml-ori
# not useful since we built with mysql. cp webapps/openmeetings/WEB-INF/classes/META-INF/mysql_persistence.xml webapps/openmeetings/WEB-INF/classes/META-INF/persistence.xml

# rant: J2EE has no idea how to not hardcode deployment parameters way deep in the code. OO code is beautiful but deployment is a lot of bash.
persistence_loc=`pwd`/webapps/openmeetings/WEB-INF/classes/META-INF/persistence.xml
sed -i 's/\\(^[[:space:]]*\\), Username=\\([^\\",]*\\)/\\1, Username=#{node["openmeetings_mysql"]["username"]}/' $persistence_loc
sed -i 's/\\(^[[:space:]]*\\), Password=\\([^\\",]*\\)/\\1, Password=#{node["openmeetings_mysql"]["password"]}/' $persistence_loc
#TODO: update the database name too? for now assume openmeetings.
CODE
 # not_if do

 # end
end

template "init.d/red5" do
  path File.join("/etc/init.d/red5")
  source "red5.erb"
  mode 0755
end

bash "setup red5 init.d script" do
  code <<-CODE
chmod +x /etc/init.d/red5
update-rc.d red5 defaults
CODE
end

