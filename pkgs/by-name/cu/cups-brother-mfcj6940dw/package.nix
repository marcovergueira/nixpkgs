{
  pkgsi686Linux,
  lib,
  stdenv,
  fetchurl,
  dpkg,
  makeWrapper,
  patchelf,
  ghostscript,
  file,
  gnused,
  gnugrep,
  coreutils,
  which,
  gawk,
  bash,
  gzip,
  perl,
}:
let
  version = "3.5.0-1";
  model = "mfcj6940dw";
  interpreter = "${pkgsi686Linux.stdenv.cc.libc}/lib/ld-linux.so.2";
in
stdenv.mkDerivation {
  pname = "cups-brother-${model}";
  inherit version;
  src = fetchurl {
    url = "https://download.brother.com/welcome/dlf105465/mfcj6940dwpdrv-${version}.i386.deb";
    hash = "sha256-kjwh8u4oX+Ae8fY4pQx7EvWUFVh3ClMxHIqJN/3krP8=";
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
    patchelf
  ];

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb -x $src $out

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    substituteInPlace $out/opt/brother/Printers/${model}/lpd/filter_${model} \
      --replace-fail /usr/bin/perl ${lib.getExe perl} \
      --replace-fail "PRINTER =~" "PRINTER = \"${model}\"; #" \
      --replace-fail "BR_PRT_PATH =~" "BR_PRT_PATH = \"$out/opt/brother/Printers/${model}/\"; #" \
      --replace-fail "my \$BRCONV=~" "my $BRCONV=\"$out/opt/brother/Printers/${model}/lpd/x86_64/br${model}filter\"; #"

    substituteInPlace $out/opt/brother/Printers/${model}/cupswrapper/brother_lpdwrapper_${model} \
      --replace-fail /usr/bin/perl ${lib.getExe perl} \
      --replace-fail "basedir =~ " "basedir = \"$out/opt/brother/Printers/${model}/\"; #" \
      --replace-fail "PRINTER =~ " "PRINTER = \"${model}\"; #" \
      --replace-fail "LPDCONFIGEXE=" "LPDCONFIGEXE=\"$out/opt/brother/Printers/${model}/lpd/i686/brprintconf_${model}\"; #"

    patchelf --set-interpreter ${interpreter} $out/opt/brother/Printers/${model}/lpd/i686/br${model}filter
    patchelf --set-interpreter ${interpreter} $out/opt/brother/Printers/${model}/lpd/i686/brprintconf_${model}

    mkdir -p $out/lib/cups/filter $out/share/cups/model
    ln -s $out/opt/brother/Printers/${model}/lpd/filter_${model} $out/lib/cups/filter/brlpdwrapper${model}
    ln -s $out/opt/brother/Printers/${model}/cupswrapper/brother_lpdwrapper_${model} $out/lib/cups/filter/brother_lpdwrapper_${model}
    ln -s $out/opt/brother/Printers/${model}/cupswrapper/brother_${model}_printer_en.ppd $out/share/cups/model/brother_${model}_printer_en.ppd

    runHook postInstall
  '';

  doCheck = true;

  dontStrip = true;

  checkPhase = ''
    echo "Running dependency checks for Brother binaries"
    set -eu

    echo "i686 loader: ${interpreter}"
    echo "x86_64 loader: ${stdenv.cc.libc}/lib/ld-linux-x86-64.so.2"

    for bin in \
      "$out/opt/brother/Printers/${model}/lpd/i686/br${model}filter" \
      "$out/opt/brother/Printers/${model}/lpd/i686/brprintconf_${model}" \
      "$out/opt/brother/Printers/${model}/lpd/x86_64/br${model}filter" \
      "$out/opt/brother/Printers/${model}/lpd/x86_64/brprintconf_${model}"
    do
      echo "---- $bin ----"
      if [ -x "$bin" ]; then
        case "$bin" in
          *"/i686/"*)
            # Use 32-bit loader to list needed libs
            "${interpreter}" --list "$bin" || true
            ;;
          *"/x86_64/"*)
            # Use 64-bit loader to list needed libs
            "${stdenv.cc.libc}/lib/ld-linux-x86-64.so.2" --list "$bin" || true
            ;;
        esac
      else
        echo "WARN: missing or not executable: $bin"
      fi
    done
  '';

  postFixup = ''
    wrapProgram $out/opt/brother/Printers/${model}/lpd/filter_${model} \
        --prefix PATH ":" ${
          lib.makeBinPath [
            ghostscript
            file
            gnused
            gnugrep
            coreutils
            which
            gawk
            bash
            gzip
          ]
        }
    wrapProgram $out/opt/brother/Printers/${model}/cupswrapper/brother_lpdwrapper_${model} \
      --prefix PATH ":" ${
        lib.makeBinPath [
          gnugrep
          coreutils
          gnused
          which
          gawk
          bash
          gzip
        ]
      }
    wrapProgram $out/opt/brother/Printers/${model}/lpd/i686/brprintconf_${model} \
      --set LD_PRELOAD "${pkgsi686Linux.libredirect}/lib/libredirect.so" \
      --set NIX_REDIRECTS /opt=$out/opt \
      --prefix LD_LIBRARY_PATH ":" "${lib.makeLibraryPath [ pkgsi686Linux.stdenv.cc.cc.lib pkgsi686Linux.zlib ]}"
    wrapProgram $out/opt/brother/Printers/${model}/lpd/i686/br${model}filter \
      --set LD_PRELOAD "${pkgsi686Linux.libredirect}/lib/libredirect.so" \
      --set NIX_REDIRECTS /opt=$out/opt \
      --prefix LD_LIBRARY_PATH ":" "${lib.makeLibraryPath [ pkgsi686Linux.stdenv.cc.cc.lib pkgsi686Linux.zlib ]}"
  '';

  meta = {
    homepage = "https://www.brother.com/";
    downloadPage = "https://support.brother.com/g/b/downloadlist.aspx?c=eu_ot&lang=en&prod=${model}_us_eu_as&os=128";
    description = "Brother MFC-J6940DW printer driver";
    license = with lib.licenses; [
      unfreeRedistributable
      gpl2Only
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "i686-linux"
    ];
    maintainers = with lib.maintainers; [ marcovergueira ];
  };
}
