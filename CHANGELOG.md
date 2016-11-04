Changelog
=========

## v0.2

- Cmdlets now return a suitable `PSCustomObject` with categorised output
- Add support for retrieving consolidated computer & operating system info (via `Get-ComputerInfo`)
- Add support for checking for & installing Windows updates (requires `PSWindowsUpdate` module)
- Add support for retrieving devices with a status other than 'OK' (**Windows 10/Server 2016 only**)
- Add support for checking for kernel & service profile crash dumps (`LocalSystem`, `LocalService` & `NetworkService`)
- Major clean-up of code (stylistic improvements, stop using `Write-Host`, etc...)

## v0.1

- Initial stable release