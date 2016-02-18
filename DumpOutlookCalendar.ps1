##vcs does not save reoccuring appointments =( probably have to code my own alternative
##powershell v3 needed for:
##  convertToJson to work
##  property check to work

$calendarFolder = "Z:\cal\";

Add-type -assembly “Microsoft.Office.Interop.Outlook” | out-null
$olFolders = “Microsoft.Office.Interop.Outlook.OlDefaultFolders” -as [type]
$outlook = new-object -comobject outlook.application
$namespace = $outlook.GetNameSpace(“MAPI”)
$folder = $namespace.getDefaultFolder($olFolders::olFolderCalendar)
#$folder.items | Select -first 10
#Select-Object -Property Subject, Start, Duration, Location

Function Remove-InvalidFileNameChars {
#http://stackoverflow.com/questions/23066783/how-to-strip-illegal-characters-before-trying-to-save-filenames
  param(
    [Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
    [String]$Name
  )

  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
  $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
  return ($Name -replace $re)
}
#EXAMPLE: Remove-InvalidFileNameChars("my**file.txt");

if(Test-Path ($calendarFolder+"uid.json")) {
    $UID = (Get-Content ($calendarFolder+"uid.json")) -join "`n" | ConvertFrom-Json
}
else {
    #folder should be empty of vcs if there isn't a uid.json
    $UID = @{};
    $UID.index = 0;
    $UID.data = New-Object PSObject;
}

$items = $folder.items #| Select -first 1
foreach ($item in $items) {
    $datePart = $item.Start.ToString("yyyyMMdd");
    $guid = $item.GlobalAppointmentID;
    $subject = Remove-InvalidFileNameChars($item.Subject);
    $filenameNoExt = $datePart+"."+$subject;
    #skip if we already have this
    #v2 and v3 compatible but probably slower
    #if([bool]($UID.data | where {$_.PropertyName -eq $guid})) {
    if([bool]($UID.data.PSobject.Properties.name -match $guid)) {
        "Skipping ["+$filenameNoExt+".vcs]";
    }
    else {
        $dupeSuffix = "";
        ## determine if we need to create a nonconflicting file
        while(Test-Path ($calendarFolder+$filenameNoExt+$dupeSuffix+".vcs")) {
            $dupeSuffix = ++$UID.index;
        }
        "Saving ["+$filenameNoExt+$dupeSuffix+".vcs]";
        #saveAs vCal type (7 - vcs): http://msdn.microsoft.com/en-us/library/aa179009(v=office.10).aspx
        $item.SaveAs($calendarFolder+$filenameNoExt+$dupeSuffix+".vcs",7);
        #$item.SaveAsICal($calendarFolder+$filenameNoExt+$dupeSuffix+".ics");
        $UID.data | Add-Member NoteProperty $guid ($filenameNoExt+$dupeSuffix+".vcs")
    }
}
$UID | ConvertTo-Json -depth 999 | Set-Content ($calendarFolder+"uid.json")

