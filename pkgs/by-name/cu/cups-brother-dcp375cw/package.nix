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
  cupsdeb = fetchurl {
    url = "https://download.brother.com/welcome/dlf005429/dcp375cwcupswrapper-${version}.i386.deb";
    hash = "sha256-ZgE2o/xU11+MzSnBYakXZE5m+Qa85/KIo31wKWAmsGY=";
  };
  lprdeb = fetchurl {
    url = "https://download.brother.com/welcome/dlf005427/dcp375cwlpr-${version}.i386.deb";
    hash = "sha256-ZgE2o/xU11+MzSnBYakXZE5m+Qa85/KIo31wKWAmsGY=";
  };
in
stdenv.mkDerivation {
  pname = "cups-brother-${model}";
  inherit version;

  srcs = [
    cupsdeb
    lprdeb
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
