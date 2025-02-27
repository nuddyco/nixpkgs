{ version, javaVersion, platforms }:

{ stdenv, lib, fetchurl, autoPatchelfHook, setJavaClassPath, makeWrapper
# minimum dependencies
, Foundation, alsa-lib, fontconfig, freetype, glibc, openssl, perl, unzip, xorg
, zlib
# runtime dependencies
, cups
# runtime dependencies for GTK+ Look and Feel
, gtkSupport ? true, cairo, glib, gtk3 }:

let
  platform = {
    aarch64-linux = "linux-aarch64";
    x86_64-linux = "linux-amd64";
    x86_64-darwin = "darwin-amd64";
  }.${stdenv.system} or (throw "Unsupported system: ${stdenv.system}");

  runtimeDependencies = [ cups ]
    ++ lib.optionals gtkSupport [ cairo glib gtk3 ];

  runtimeLibraryPath = lib.makeLibraryPath runtimeDependencies;

  javaVersionPlatform = "${javaVersion}-${platform}";

  graalvmXXX-ce = stdenv.mkDerivation rec {
    name = "graalvm${javaVersion}-ce";
    srcs = [
      (fetchurl {
        sha256 = {
          "8-linux-amd64" = "01gyxjmfp7wpcyn7x8b184fn0lp3xryfw619bqch120pzvr6z88f";
          "11-linux-aarch64" = "sha256-u9841eaHH347JHCrm5u3YGZ9RSTuKiDq368TY2otAYw=";
          "11-linux-amd64" = "0w7lhvxm4nggqdcl4xrhdd3y6dqw9jhyca9adjkp508n4lqf1lxv";
          "11-darwin-amd64" = "0dnahicdl0vhrbiml9z9nbb7k75hbsjj8rs246i1lwril12dqb7n";
        }.${javaVersionPlatform};
        url = "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${version}/graalvm-ce-java${javaVersionPlatform}-${version}.tar.gz";
      })
      (fetchurl {
        sha256 = {
          "8-linux-amd64" = "1jlvrxdlbsmlk3ia43h9m29kmmdn83h6zdlnf8qb7bm38c84nhsc";
          "11-linux-aarch64" = "sha256-7W5gkhj2kON2ocrGpyH/OL/phOyHkjNDId2CtyUAEWY=";
          "11-linux-amd64" = "1ybd7a6ii6582skr0nkxx7bccsa7gkg0yriql2h1lcz0rfzcdi3g";
          "11-darwin-amd64" = "1jdy845vanmz05zx5b9227gb1msh9wdrz2kf3fx9z54ssd9qgdhm";
        }.${javaVersionPlatform};
        url = "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${version}/native-image-installable-svm-java${javaVersionPlatform}-${version}.jar";
      })
      (fetchurl {
        sha256 = {
          "8-linux-amd64" = "18ip0ay06q1pryqs8ja988mvk9vw475c0nfjcznnsd1zp296p6jc";
          "11-linux-aarch64" = "sha256-i9ysgqbI52PiXofZQ5AnPSzs2TeR8An5CIYzcwhx28o=";
          "11-linux-amd64" = "1jszz97mkqavxzyhx5jxhi43kqjxk9c36j5l5hy3kn8sdfmbplm4";
          "11-darwin-amd64" = "1767ryhv2cn5anlys63ysax1p8ag79bykac1xfrjfan8yv6d8ybl";
        }.${javaVersionPlatform};
        url = "https://github.com/oracle/truffleruby/releases/download/vm-${version}/ruby-installable-svm-java${javaVersionPlatform}-${version}.jar";
      })
      (fetchurl {
        sha256 = {
          "8-linux-amd64" = "08s36rjy5irg25b7lqx0m4v2wpywin3cqyhdrywhvq14f7zshsd5";
          "11-linux-aarch64" = "sha256-Lkc/mq1w18+PQ5McvLGyQBSOz/TMSUgwioRZ0Dtyhm4=";
          "11-linux-amd64" = "1ybjaknmbsdg8qzb986x39fq0h7fyiymdcigc7y86swk8dd916hv";
          "11-darwin-amd64" = "02dwlb62kqr4rjjmvkhn2xk9l1p47ahg9xyyfkw7im1jwlqmqnzf";
        }.${javaVersionPlatform};
        url = "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${version}/wasm-installable-svm-java${javaVersionPlatform}-${version}.jar";
      })
    ] ++ lib.optionals (platform == "amd64") [
      # graalpython is not available on aarch64 platforms yet
      (fetchurl {
        sha256 = {
          "8-linux-amd64" = "0il15438qnikqsxdsl7fcdg0c8zs3cbm4ry7pys7fxxr1ckd8szq";
          "11-linux-amd64" = "07759sr8nijvqm8aqn69x9vq7lyppns7a6l6xribv43jvfmwpfkl";
          "11-darwin-amd64" = "01l3as8dihc7xqy5sdkrpxmpzrqbcvvg84m2s6j1j8y2db1khf2s";
        }.${javaVersionPlatform};
        url = "https://github.com/graalvm/graalpython/releases/download/vm-${version}/python-installable-svm-java${javaVersionPlatform}-${version}.jar";
      })
    ];

    buildInputs = lib.optionals stdenv.isLinux [
      alsa-lib # libasound.so wanted by lib/libjsound.so
      fontconfig
      freetype
      openssl # libssl.so wanted by languages/ruby/lib/mri/openssl.so
      stdenv.cc.cc.lib # libstdc++.so.6
      xorg.libX11
      xorg.libXext
      xorg.libXi
      xorg.libXrender
      xorg.libXtst
      zlib
    ];

    # Workaround for libssl.so.10 wanted by TruffleRuby
    # Resulting TruffleRuby cannot use `openssl` library.
    autoPatchelfIgnoreMissingDeps = true;

    nativeBuildInputs = [ unzip perl autoPatchelfHook makeWrapper ];

    unpackPhase = ''
      unpack_jar() {
        jar=$1
        unzip -q -o $jar -d $out
        perl -ne 'use File::Path qw(make_path);
                  use File::Basename qw(dirname);
                  if (/^(.+) = (.+)$/) {
                    make_path dirname("$ENV{out}/$1");
                    system "ln -s $2 $ENV{out}/$1";
                  }' $out/META-INF/symlinks
        perl -ne 'if (/^(.+) = ([r-])([w-])([x-])([r-])([w-])([x-])([r-])([w-])([x-])$/) {
                    my $mode = ($2 eq 'r' ? 0400 : 0) + ($3 eq 'w' ? 0200 : 0) + ($4  eq 'x' ? 0100 : 0) +
                               ($5 eq 'r' ? 0040 : 0) + ($6 eq 'w' ? 0020 : 0) + ($7  eq 'x' ? 0010 : 0) +
                               ($8 eq 'r' ? 0004 : 0) + ($9 eq 'w' ? 0002 : 0) + ($10 eq 'x' ? 0001 : 0);
                    chmod $mode, "$ENV{out}/$1";
                  }' $out/META-INF/permissions
        rm -rf $out/META-INF
      }

      mkdir -p $out
      arr=($srcs)

      # The tarball on Linux has the following directory structure:
      #
      #   graalvm-ce-java11-20.3.0/*
      #
      # while on Darwin it looks like this:
      #
      #   graalvm-ce-java11-20.3.0/Contents/Home/*
      #
      # We therefor use --strip-components=1 vs 3 depending on the platform.
      tar xf ''${arr[0]} -C $out --strip-components=${
        if stdenv.isLinux then "1" else "3"
      }

      # Sanity check
      if [ ! -d $out/bin ]; then
         echo "The `bin` is directory missing after extracting the graalvm"
         echo "tarball, please compare the directory structure of the"
         echo "tarball with what happens in the unpackPhase (in particular"
         echo "with regards to the `--strip-components` flag)."
         exit 1
      fi

      for jar in "''${arr[@]:1}"; do
        unpack_jar "$jar"
      done
    '';

    outputs = [ "out" "lib" ];

    installPhase = let
      nativePRNGWorkaround = path: ''
        # BUG workaround http://mail.openjdk.java.net/pipermail/graal-dev/2017-December/005141.html
        substituteInPlace ${path} \
          --replace file:/dev/random    file:/dev/./urandom \
          --replace NativePRNGBlocking  SHA1PRNG
      '';
      copyClibrariesToOut = basepath: ''
        # provide libraries needed for static compilation
        for f in ${glibc}/lib/* ${glibc.static}/lib/* ${zlib.static}/lib/*; do
          ln -s $f ${basepath}/${platform}/$(basename $f)
        done
      '';
      copyClibrariesToLib = ''
        # add those libraries to $lib output too, so we can use them with
        # `native-image -H:CLibraryPath=''${graalvm11-ce.lib}/lib ...` and reduce
        # closure size by not depending on GraalVM $out (that is much bigger)
        mkdir -p $lib/lib
        for f in ${glibc}/lib/*; do
          ln -s $f $lib/lib/$(basename $f)
        done
      '';
    in {
      "8-linux-amd64" = ''
        ${nativePRNGWorkaround "$out/jre/lib/security/java.security"}

        ${copyClibrariesToOut "$out/jre/lib/svm/clibraries"}

        ${copyClibrariesToLib}

        # allow using external truffle-api.jar and languages not included in the distrubution
        rm $out/jre/lib/jvmci/parentClassLoader.classpath
      '';
      "11-linux-amd64" = ''
        ${nativePRNGWorkaround "$out/conf/security/java.security"}

        ${copyClibrariesToOut "$out/lib/svm/clibraries"}

        ${copyClibrariesToLib}
      '';
      "11-linux-aarch64" = ''
        ${nativePRNGWorkaround "$out/conf/security/java.security"}

        ${copyClibrariesToOut "$out/lib/svm/clibraries"}

        ${copyClibrariesToLib}
      '';
      "11-darwin-amd64" = ''
        # create empty $lib/lib to avoid breaking builds
        mkdir -p $lib/lib
        ${nativePRNGWorkaround "$out/conf/security/java.security"}
      '';
    }.${javaVersionPlatform} + ''
      # jni.h expects jni_md.h to be in the header search path.
      ln -s $out/include/linux/*_md.h $out/include/
    '';

    dontStrip = true;

    preFixup = ''
      # We cannot use -exec since wrapProgram is a function but not a
      # command.
      #
      # jspawnhelper is executed from JVM, so it doesn't need to wrap it,
      # and it breaks building OpenJDK (#114495).
      for bin in $( find "$out" -executable -type f -not -path '*/languages/ruby/lib/gems/*' -not -name jspawnhelper ); do
        if patchelf --print-interpreter "$bin" &> /dev/null || head -n 1 "$bin" | grep '^#!' -q; then
          wrapProgram "$bin" \
            --prefix LD_LIBRARY_PATH : "${runtimeLibraryPath}"
        fi
      done

      # copy-paste openjdk's preFixup
      # Set JAVA_HOME automatically.
      mkdir -p $out/nix-support
      cat <<EOF > $out/nix-support/setup-hook
        if [ -z "\''${JAVA_HOME-}" ]; then export JAVA_HOME=$out; fi
      EOF

      find "$out" -name libfontmanager.so -exec \
        patchelf --add-needed libfontconfig.so {} \;
    '';

    # $out/bin/native-image needs zlib to build native executables.
    propagatedBuildInputs = [ setJavaClassPath zlib ] ++
      # On Darwin native-image calls clang and it
      # tries to include <Foundation/Foundation.h>,
      # and Interactive Ruby (irb) requires OpenSSL
      # headers.
      lib.optionals stdenv.hostPlatform.isDarwin [ Foundation openssl ];

    doInstallCheck = true;
    installCheckPhase = ''
      echo ${
        lib.escapeShellArg ''
          public class HelloWorld {
            public static void main(String[] args) {
              System.out.println("Hello World");
            }
          }
        ''
      } > HelloWorld.java
      $out/bin/javac HelloWorld.java

      # run on JVM with Graal Compiler
      $out/bin/java -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler HelloWorld | fgrep 'Hello World'

      # Ahead-Of-Time compilation
      $out/bin/native-image -H:-CheckToolchain -H:+ReportExceptionStackTraces --no-server HelloWorld
      ./helloworld | fgrep 'Hello World'

      ${
        lib.optionalString stdenv.isLinux ''
          # Ahead-Of-Time compilation with --static
          # --static flag doesn't work for darwin
          $out/bin/native-image --no-server --static HelloWorld
          ./helloworld | fgrep 'Hello World'
        ''
      }

      ${
        lib.optionalString (platform == "amd64") ''
          echo "Testing interpreted languages"
          $out/bin/graalpython -c 'print(1 + 1)'
          $out/bin/ruby -e 'puts(1 + 1)'

          echo '1 + 1' | $out/bin/graalpython
        ''
      }

      ${# TODO: `irb` on MacOS gives an error saying "Could not find OpenSSL
        # headers, install via Homebrew or MacPorts or set OPENSSL_PREFIX", even
        # though `openssl` is in `propagatedBuildInputs`. For more details see:
        # https://github.com/NixOS/nixpkgs/pull/105815
        # TODO: "truffleruby: an internal exception escaped out of the interpreter"
        # error on linux-aarch64
        lib.optionalString (platform == "linux-amd64") ''
          echo '1 + 1' | $out/bin/irb
        ''
      }

      ${# TODO: Doesn't work on MacOS, we have this error:
        # "Launching JShell execution engine threw: Operation not permitted (Bind failed)"
        lib.optionalString (javaVersion == "11" && stdenv.isLinux) ''
          echo '1 + 1' | $out/bin/jshell
        ''
      }'';

    passthru.home = graalvmXXX-ce;

    meta = with lib; {
      homepage = "https://www.graalvm.org/";
      description = "High-Performance Polyglot VM";
      license = with licenses; [ upl gpl2Classpath bsd3 ];
      maintainers = with maintainers; [
        bandresen
        volth
        hlolli
        glittershark
        babariviere
        ericdallo
        thiagokokada
      ];
      platforms = platforms;
    };
  };
in graalvmXXX-ce
