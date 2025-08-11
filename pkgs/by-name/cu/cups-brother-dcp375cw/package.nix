{
  lib,
  stdenv,
  fetchurl,
  cups,
  dpkg,
  gnused,
  makeWrapper,
  ghostscript,
  file,
  a2ps,
  coreutils,
  gnugrep,
  which,
  gawk,
  pkgsi686Linux,
}:
let
  version = "1.1.3-1";
  model = "dcp375cw";
  cupswrapper = fetchurl {
    url = "https://download.brother.com/welcome/dlf005429/dcp375cwcupswrapper-${version}.i386.deb";
    hash = "sha256-miVXKLWV0mZ7LK+dDTMrZ34aaCmj7B7W1OkApEBpzy0=";
  };
  lpr = fetchurl {
    url = "https://download.brother.com/welcome/dlf005427/dcp375cwlpr-${version}.i386.deb";
    hash = "sha256-ba8BRLWALqjaOUyhTbDm8CANQElUVkkoN5H4mbf3vSY=";
  };
in
stdenv.mkDerivation {
  pname = "cups-brother-${model}";
  inherit version;

  srcs = [
    cupswrapper
    lpr
  ];

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  buildInputs = [
    cups
    ghostscript
    a2ps
    gawk
    pkgsi686Linux.stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb -x ${lpr} $out
    dpkg-deb -x ${cupswrapper} $out

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    interpreter=${
      if stdenv.hostPlatform.system == "x86_64-linux"
      then "${pkgsi686Linux.glibc.out}/lib/ld-linux.so.2"
      else "${stdenv.cc.libc.out}/lib/ld-linux.so.2"
    }

    substituteInPlace $out/opt/brother/Printers/${model}/lpd/filter${model} \
      --replace /opt "$out/opt"

    substituteInPlace $out/opt/brother/Printers/${model}/inf/br${model}rc \
      --replace "PaperType=Letter" "PaperType=A4"

    patchelf --set-interpreter "$interpreter" "$out/opt/brother/Printers/${model}/lpd/br${model}filter" \
      --set-rpath ${
        lib.makeLibraryPath (
          if stdenv.hostPlatform.system == "x86_64-linux"
          then [ pkgsi686Linux.stdenv.cc.cc ]
          else [ stdenv.cc.cc ]
        )
      }

    mkdir -p $out/lib/cups/filter/
    ln -s $out/opt/brother/Printers/${model}/lpd/filter${model} $out/lib/cups/filter/brlpdwrapper${model}

    wrapProgram $out/opt/brother/Printers/${model}/lpd/filter${model} \
      --prefix PATH ":" ${
        lib.makeBinPath [
          gawk
          ghostscript
          a2ps
          file
          gnused
          gnugrep
          coreutils
          which
        ]
      }

    for f in $out/opt/brother/Printers/${model}/cupswrapper/cupswrapper${model}; do
      wrapProgram $f --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          ghostscript
          gnugrep
          gnused
        ]
      }
    done

    mkdir -p $out/share/cups/model
    ln -s $out/opt/brother/Printers/${model}/cupswrapper/brother_${model}_printer_en.ppd $out/share/cups/model/
    
    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://www.brother.com/";
    description = "Brother ${model} printer driver";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    platforms = [ "i686-linux" "x86_64-linux" ];
    downloadPage = "https://support.brother.com/g/b/downloadlist.aspx?c=gb&lang=en&prod=${model}_all&os=128";
    maintainers = with maintainers; [ marcovergueira ];
  };
}
