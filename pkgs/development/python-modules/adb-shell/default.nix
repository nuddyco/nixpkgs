{ lib
, aiofiles
, buildPythonPackage
, cryptography
, fetchFromGitHub
, isPy3k
, libusb1
, mock
, pyasn1
, pycryptodome
, pytestCheckHook
, rsa
}:

buildPythonPackage rec {
  pname = "adb-shell";
  version = "0.4.1";

  disabled = !isPy3k;

  # pypi does not contain tests, using github sources instead
  src = fetchFromGitHub {
    owner = "JeffLIrion";
    repo = "adb_shell";
    rev = "v${version}";
    sha256 = "sha256-E7sX+N6d5Otwp1AbdPCnQJ2YT/k89+6kMJDLt8U2Dsg=";
  };

  propagatedBuildInputs = [
    aiofiles
    cryptography
    libusb1
    pyasn1
    rsa
  ];

  checkInputs = [
    mock
    pycryptodome
    pytestCheckHook
  ];

  pythonImportsCheck = [ "adb_shell" ];

  meta = with lib; {
    description = "Python implementation of ADB with shell and FileSync functionality";
    homepage = "https://github.com/JeffLIrion/adb_shell";
    license = licenses.asl20;
    maintainers = with maintainers; [ jamiemagee ];
  };
}
