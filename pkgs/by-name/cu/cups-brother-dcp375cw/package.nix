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
}:

let
  version = "1.1.3-1";
  model = "dcp375cw";
  cups = fetchurl {
    url = "https://download.brother.com/welcome/dlf005429/dcp375cwcupswrapper-${version}.i386.deb";
    sha256 = "9a255728b595d2667b2caf9d0d332b677e1a6829a3ec1ed6d4e900a44069cf2d";
  };
  lpr = fetchurl {
    url = "https://download.brother.com/welcome/dlf005427/dcp375cwlpr-${version}.i386.deb";
    sha256 = "6daf0144b5802ea8da394ca14db0e6f0200d4049545649283791f899b7f7bd26";
  };
in
stdenv.mkDerivation {
    pname = "cups-brother-${model}";
    inherit version;

    srcs = [
      cups
      lpr
    ];

    nativeBuildInputs = [
      # dpkg
      makeWrapper
    ];

    buildInputs = [
      cups
      ghostscript
      a2ps
      gawk
    ];

    unpackPhase = ''
      runHook preUnpack

      dpkg-deb -x ${lpr} $out
      dpkg-deb -x ${cups} $out

      runHook postUnpack
    '';

    installPhase = ''
      substituteInPlace $out/opt/brother/Printers/${model}/lpd/filter${model} \
      --replace /opt "$out/opt"

      substituteInPlace $out/opt/brother/Printers/${model}/inf/br${model}rc \
      --replace "PaperType=Letter" "PaperType=A4"

      patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) \
      $out/opt/brother/Printers/${model}/lpd/br${model}filter

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
    '';

    meta = with lib; {
      homepage = "https://www.brother.com/";
      description = "Brother ${model} printer driver";
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      license = licenses.unfree;
      platforms = platforms.linux;
      downloadPage = "https://support.brother.com/g/b/downloadlist.aspx?c=gb&lang=en&prod=${model}_all&os=128";
      maintainers = with maintainers; [ marcovergueira ];
    };
}
