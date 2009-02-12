Panda
=====

Panda is an open source solution for video uploading, encoding and streaming.

Please see [pandastream.com](http://pandastream.com/) for an introduction and lots of documentation.

Information beyond this point is aimed at people who want to contribute to panda and / or understand how it works.

How does Panda work?
====================

1. Video is uploaded to panda
2. Panda checks the video's metadata, uploads the raw file to S3 and adds it to the encoding queue
3. The encoder application picks the encoding job off the queue when it's free and encodes the video to all possible formats
4. Panda sends a callback to your web application notifying you the video has been encoded
5. You use the appropriate S3 url of the encoding to embed the video

Installation and setup
======================

Please note that this guide has only been tested on OSX. Please post modifications to the google group if you try another platform.

Install dependencies
--------------------

First install the following gems

    sudo gem install merb merb_helpers activesupport RubyInline amazon_sdb aws-s3 uuid flvtool2

Next you'll need to install libgd, ffmpeg, and the rvideo gem:

### [LibGD](http://www.libgd.org/Main_Page)

#### On OSX (using macports)

Installing gd2 with macports seems to be the fastest way to install the required dependencies:

    sudo port install gd2

For some reason (which I've not really looked into) the macports install doesn't quite install everything so you still need to install libgd itself (but not the dependencies) from source:

    mkdir -p ~/src && cd ~/src
    curl http://www.libgd.org/releases/gd-2.0.35.tar.gz > gd-2.0.35.tar.gz
    tar zxvf gd-2.0.35.tar.gz
    cd gd-2.0.35 && ./configure && make && sudo make install

Alternatively, if you want to build everything from source, see [this tutorial](http://mikewest.org/archive/installing-libgd-from-source-on-os-x). Here's a [possible gotcha](http://www.libgd.org/FAQ#gd_keeps_saying_it_can.27t_find_png_or_jpeg_support._I_did_install_libpng_and_libjpeg._What_am_I_missing.3F).

#### Other platforms

The following libraries are required by libgd:

* [zlib](http://www.zlib.net)
* [libjpeg](http://www.ijg.org/)
* [libgd](http://www.libgd.org/Main_Page)

Install [libjpeg](http://www.ijg.org/) from source:

    mkdir -p ~/src && cd ~/src
    wget ftp://ftp.uu.net/graphics/jpeg/jpegsrc.v6b.tar.gz
    tar zxvf jpegsrc.v6b.tar.gz
    cd jpeg-6b && ./configure && make && sudo make install

Install libgd from source:

      mkdir -p ~/src && cd ~/src
      curl http://www.libgd.org/releases/gd-2.0.35.tar.gz > gd-2.0.35.tar.gz
      tar zxvf gd-2.0.35.tar.gz
      cd gd-2.0.35 && ./configure && make && sudo make install

### RVideo (0.9.4)

Currently we can't use `sudo gem install rvideo` since that installs 0.9.3.

    svn checkout svn://rubyforge.org/var/svn/rvideo/trunk rvideo
    cd rvideo
    rake install_gem

Install the rvideo tools (on OS X at least - your system may differ). You might want to check your gem library location (`gem env`).

    sudo cp lib/rvideo/tools/*.rb /Library/Ruby/Gems/1.8/gems/rvideo-0.9.4/lib/rvideo/tools/.

### FFMPEG

Available in all good package repositories including Darwin Ports.

    sudo port install ffmpeg +x264 +faac

If you're developing on Mac OS X, you can save some time by [grabbing ffmpeg out of the ffmpegX application instead of compiling it](http://www.macosxhints.com/article.php?story=20061220082125312).

Grab Panda
----------
Get the latest (at this moment, our code is compatible with 0.9.7)

    git clone git://github.com/newbamboo/panda.git

Development work is merged regularly into the master branch. If you have difficulty running try the stable branch which tracks releases.

You should follow the [getting started guide](http://pandastream.com/docs/getting_started#configure_panda) from the configure panda section onwards. You'll probably want to use the [filesystem storage option](http://pandastream.tumblr.com/post/54322685/panda-1-2-released) and also [emulate SimpleDB locally](http://pandastream.tumblr.com/post/52779609/playing-with-panda-without-simpledb-account).

Further information
===================

Investigating encoding errors
-----------------------------

When an encoding fails the status of the video is set to 'error' and the output of ffmpeg is saved on S3 with the filename `video_token.error`.

SimpleDB
========

Please refer to [amazon\_sdb](http://nytimes.rubyforge.org/amazon_sdb/) for how to access simpledb. Here are some examples.

Extracting All info 

    >> Profile.query

Extracting specific info

    >> Profile.query("['audio_coded' = 'aac']")

Deleting a profile.

    >> profile = Profile.query("['title'='Flash h264 SD']")
    >> profile.destroy!

Videos schema
-------------

    filename # 976a4b00-16cc-012b-7316-001ec2b5c0e1.flv
    original_filename # sneezing_panda.flv
    parent

    status # original, queued, processing, done, error

    duration
    container
    width
    height

    video_codec
    video_bitrate
    fps
    audio_codec
    audio_sample_rate

    profile # id of encoding profile used
    profile_title

    updated_at
    created_at

Encoding profiles schema
------------------------

    title

    container
    width
    height

    video_codec
    video_bitrate
    fps
    audio_codec
    audio_bitrate
    audio_sample_rate

    updated_at
    created_at
