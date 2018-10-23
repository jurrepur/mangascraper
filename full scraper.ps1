<################################################
Mangaleecher-leecher.
This script leeches manga from mangaleechers and saves it locally

Currently supported websites:
    Mangasee
    Mangakakalot
    Manganelo
################################################>

Remove-Variable * -ErrorAction SilentlyContinue

#place your manga here:

$mangalist = (
    "Grand Blue",
    "Demi-chan wa kataritai",
    "Hinamatsuri"
)

#directory where the manga is saved, change to your liking, but don't forget the \ at the end
$folder = "E:\manga\"

<#############################
1. CHECK VALIDITY OF MANGA LIST
check if the manga exists on one of the websites.
With mangakakalot this has to be done by scraping the entire HTML code of the website and checking for a page not found because
mangakakalot doesn't return proper html statusus (it returns a 200 when the page doesnt exist instead of a 400

sort the checks with the least popular on top, the script will rip from the lowest website which has the manga
##############################>
"----------------------------------------------"
"-----------------finding manga----------------"
"----------------------------------------------"



$stop = 0   #1 if any manga haven't been found, stops the program after searching the entire list

for ([int]$manga=0; $manga -lt $mangalist.length; $manga++) {
    "checking if manga exists: " + $mangalist[$manga]
    $found = 0  #1 if the manga has been found, stops the program from searching the manga on other websites it already determined it has been found
    
    #check mangasee 
    if($found -eq 0){  #if not found yet
        $Url = ("http://mangaseeonline.us/manga/"+$mangalist[$manga].replace(' ','-'))    #create url
        $error.Clear()  #clear errors
        try{ $request = Invoke-WebRequest -Uri $Url }catch{}   #try the url     
        if($Error.Count -eq 0){   #if no error was generated (mostly 404 page not found)
            $found = 1            #manga was found, stop checking other sites
        }
    }    
       
    #check on mangakakalot by searching the html source because the site doesn't follow proper HTML codes
    if($found -eq 0){
        $Url = ("http://mangakakalot.com/manga/"+($mangalist[$manga].replace(' ','_')).replace('-',''))
        $web = New-Object Net.WebClient       #download HTML source
        $web | Get-Member > $null
        $HTML = $web.DownloadString($Url)
        if( -not($HTML -match "Sorry, the page you have requested cannot be found.")){   #if this string was found
            $found = 1 
        }
    }
    

    #check manganelo
    if($found -eq 0){ 
        $Url = ("http://manganelo.com/manga/"+($mangalist[$manga].replace(' ','_')).replace('-',''))
        $error.Clear()
        try{ $request = Invoke-WebRequest -Uri $Url }catch{}        
        if($Error.Count -eq 0){
            $found.Item($manga) = 1
        }
    }

    #if manga is unknown, print so
    if($found -eq 0){        
        Write-Host "!!!Unknown manga:"$mangalist[$manga] -ForegroundColor red
        $stop = 1   #make the program stop after checkint the entire list
    }

}
#if an manga wasnt found, abort the program
if($stop -ne  0){
    "unknown manga's found, please check your mangalist - aborting the script" 
    exit
}



<#############################
do all per manga
##############################>
    "----------------------------------------------"
    "----------------updating manga----------------"
    "----------------------------------------------"


for ($manga=0; $manga -lt $mangalist.length; $manga++) {
    <#############################
    2. CHECK LOCAL FILES
    Check which chapter's have already been downloaded on your PC
    ##############################>
    #create new folders
    New-Item -ItemType Directory -Force -Path ($folder+$mangalist[$manga]) | Out-Null
    #get latest volume inside the manga folder
    $maxvol = 0;
    if(Test-Path ($folder+$mangalist[$manga]+"/Vol 1")){ 
        while(Test-Path ($folder+$mangalist[$manga]+"/Vol "+($maxvol+1))){
            $maxvol++;
        }   
    }

    #check latest chapter
    $maxchap = 0;  #latest chapter as string
    $chapnumber = 0    #latest chap as integer
    $maxchapvol = 0;  #latest chapter in a volume as string
    $chapnumbervol = 0    #latest chapter in a volume as integer

    #get the latest chapter in the top level folder
    $dir = ($folder+$mangalist[$manga])
    $AllFiles = Get-ChildItem $dir "*.jpg"
    if($AllFiles.Length -ne 0){
        foreach($file in $AllFiles){
            if($File.Name.SubString(0,4) -gt $maxchap){
                $maxchap = $File.Name.SubString(0,4)
            }
        }
        $maxchap = $maxchap.TrimStart('0')
        $chapnumber = [int]$maxchap
        $chapnumber++
    }

    #if volumes exists, get the latest chapter from the latest volume
    if($maxvol -ne 0){
        $dir = ($folder+$mangalist[$manga]+"/Vol "+$maxvol)        
        $AllFiles = Get-ChildItem $dir "*.jpg"
        if($AllFiles.Length -ne 0){
            foreach($file in $AllFiles){
                if($File.Name.SubString(0,4) -gt $maxchapvol){
                    $maxchapvol = $File.Name.SubString(0,4)
                }
            }
            $maxchapvol = $maxchapvol.TrimStart('0')
            $chapnumbervol = [int]$maxchapvol
            $chapnumbervol++
        }
    }

    #if lastest chapter in volume was higher, copy the value to chapnumber
    if($chapnumbervol -gt $chapnumber){
        $chapnumber = $chapnumbervol
    }



    <#############################
    3. Scrape images
    Check if new chapters exist, and download these
    ##############################>
    $try = 0
    while(1){        
        $success = 0 #if 1, the chapter has been downloaded already from another website, stop trying other websites
        $dir = ($folder+$mangalist[$manga])  #always dump in the main folder
                
        #check mangasee for update
        if($success -eq 0){
            $Url = "http://mangaseeonline.us/read-online/"+($mangalist[$manga].replace(' ','-'))+"-chapter-"+($chapnumber)+".html"
            $error.Clear()
            try{ $request = Invoke-WebRequest -Uri $Url }catch{}
            if ($error.Count -lt 1) {      
                Write-Host("**new chapter "+$chapnumber+" found on mangasee for " + $mangalist[$manga]) -ForegroundColor green
                $iwr = Invoke-WebRequest -Uri $Url
                $wc = New-Object System.Net.WebClient
                $images = ($iwr).Images | select src
                try{
                    $images | foreach {
                    #if it is an actual image and not the site logo
                        if([io.path]::GetFileName($_.src) -like '*-*'){
                            $wc.DownloadFile( $_.src, ("$dir\"+[io.path]::GetFileNameWithoutExtension($_.src)+".jpg"))
                        }
                    }
                }
                catch{}
                $success = 1;
                $try = 0 
            }
        }

        #try on mangakakalot if it hasn't been found already
        $Url = "http://mangakakalot.com/chapter/"+($mangalist[$manga].replace(' ','_')).replace('-','')+"/chapter_"+($chapnumber)
        if($success -eq 0){
            $web = New-Object Net.WebClient
            $web | Get-Member > $null
            $HTML = $web.DownloadString($Url)
            #if it contains image 1
            if($HTML -match "1.jpg"){
                Write-Host ("**new chapter "+$chapnumber+" found on mangakakalot for " + $mangalist[$manga]) -ForegroundColor green
                $iwr = Invoke-WebRequest -Uri $Url
                $wc = New-Object System.Net.WebClient
                $images = ($iwr).Images | select src
                $images | foreach {
                    if([io.path]::GetFileNameWithoutExtension($_.src) -match "^\d+$"){
                        $wc.DownloadFile( $_.src, ("$dir\"+($chapnumber.ToString() +"-"+ [io.path]::GetFileNameWithoutExtension($_.src).PadLeft(4, '0')+".jpg").PadLeft(13,'0')))
                    }
                }
            $success = 1;
            $try = 0  
            }
        }
        #try on manganelo if it hasn't been found already
        if($success -eq 0){
            $Url = "http://manganelo.com/chapter/"+($mangalist[$manga].replace(' ','_')).replace('-','')+"/chapter_"+($chapnumber)
            $web = New-Object Net.WebClient
            $web | Get-Member > $null
            $HTML = $web.DownloadString($Url)
            #if it contains image 1
            if($HTML -match "1.jpg"){
                Write-Host ("**new chapter "+$chapnumber+" found on manganelo for " + $mangalist[$manga]) -ForegroundColor green
                $iwr = Invoke-WebRequest -Uri $Url
                $wc = New-Object System.Net.WebClient
                $images = ($iwr).Images | select src
                $images | foreach {
                    if([io.path]::GetFileNameWithoutExtension($_.src) -match "^\d+$"){
                        $wc.DownloadFile( $_.src, ("$dir\"+($chapnumber.ToString() +"-"+ [io.path]::GetFileNameWithoutExtension($_.src).PadLeft(4, '0')+".jpg").PadLeft(13,'0')))
                    }
                }           
            $success = 1;
            $try = 0 
            }
        }    

        if($success -eq 0){
            $try++
            if($try -eq 2){
                "no new chapters foud for " + $mangalist[$manga] + ", latest chapter: "+($chapnumber-2)
                break
            }
        }
        $chapnumber++
    }
}

"program ran succesfully, all manga updated"

#prevent script from closing automaticcaly so the user can see all updates
Read-Host -Prompt "Press Enter to exit"
