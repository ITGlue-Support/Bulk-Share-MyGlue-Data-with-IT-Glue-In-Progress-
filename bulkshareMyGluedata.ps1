###################### For GUI ##################################
Add-Type -AssemblyName Microsoft.VisualBasic
################ Create CSV ######################################

$newcsv = {} | Select-Object 'Record_id', 'Organization','Record_Type','Record_Name','Restricted' | Export-Csv -NoTypeInformation MyGlue_records.csv
$Global:csvfile = Import-Csv MyGlue_records.csv

#﻿############### Authorization Token ###############################

function authorization_token
{
    param (
        
        [string]$email,
        [string]$password,
        [int]$otp
    
    )

$body = @"
{
    "user":
    {
        "email": "$email",
        "password":  "$password",
        "otp_attempt": "$otp"
    }
}

"@
try{

    $auth_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $auth_headers.Add("Content-Type", "application/json")

    $gen_jwt_url = "https://app.myglue.com/login?generate_jwt=1"

    $gen_jwt = Invoke-RestMethod -Uri $gen_jwt_url -Method 'POST' -Body $body -Headers $auth_headers

    $gen_access_token_url = "https://app.myglue.com/jwt/token?refresh_token=$($gen_jwt.token)"

    $gen_access_token = Invoke-RestMethod -Uri $gen_access_token_url -Method 'GET' -Headers $auth_headers
    
    $access_token = $gen_access_token.token

    Write-Host "Authorizatoin complete!" -ForegroundColor Green

    set_header -token "$access_token"
}
catch{

    Write-Host "Unable to authorize with provided credentials: $($_.exception.message)" -ForegroundColor Red
    break
}

}
################### Headers ###################################
function set_header {
    param (

        [string]$token
    
    )

    $global:headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $global:headers.Add("Content-Type", "application/json")
    $global:headers.Add("Authorization", "Bearer $token")

}
#################### Add Document/Pass_folder info ###########################################################################

function add_df_csv {

    param (
    
        [string]$id,
        [string]$org_id,
        [string]$type
    
    )

    try{
    
        $csv_url = "https://api.itglue.com/organizations/$org_id/relationships/$type" + "?filter[id]=$id"

        $csv_data = Invoke-RestMethod -Uri $csv_url -Method 'GET' -Headers $headers

        $csvfile | select @{N="record_id";E={$id}},@{N="organization";E={$($csv_data.data.attributes.'organization-name')}},@{N="record_type";E={$type}},@{N="record_name";E={$($csv_data.data.attributes.name)}}, @{N="restricted";E={$($csv_data.data.attributes.restricted)}} | export-CSV MyGlue_records.csv -Append -NoTypeInformation

        }
        catch {
        
            Write-Host "Issue occured when adding the asset with ID: $id and type $type, info into the CSV file. Error: $($_.exception.message)!" -ForegroundColor -Red
        }


}
################### Add the recrods that do not allow to update name and notes ###################################

function add_to_csv {

    param (
    
        [string]$id,
        [string]$type
    
    )

    try{
    
        $csv_url = "https://api.itglue.com//$type/$id"

        $csv_data = Invoke-RestMethod -Uri $csv_url -Method 'GET' -Headers $headers

        $csvfile | select @{N="record_id";E={$id}},@{N="organization";E={$($csv_data.data.attributes.'organization-name')}},@{N="record_type";E={$type}},@{N="record_name";E={$($csv_data.data.attributes.name)}}, @{N="restricted";E={$($csv_data.data.attributes.restricted)}} | export-CSV MyGlue_records.csv -Append -NoTypeInformation

        }
        catch {
        
            Write-Host "Issue occured when adding the asset with ID: $id and type $type, info into the CSV file. Error: $($_.exception.message)!" -ForegroundColor -Red
        }


}

################## Update Security on the MyGlue Asset ###########

function update_asset_security {

    param(
        [string]$type,
        [string]$id
    
    )

   Write-Host "Updating the security permission....." -ForegroundColor DarkYellow

   $uas_url = "https://api.itglue.com/$type/$id/relationships/resource_accesses"

   $body = @"
{
    "data": [
        {
            "type": "resource_accesses",
            "attributes": {
                "accessor-id": "$ITG_group_id",
                "accessor-type": "Group"
            }
        }
    ]
}
"@
    try{

        $update = Invoke-RestMethod -Uri $uas_url -Method 'PATCH' -Headers $headers -Body $body

        Write-Host "Permissions updated successfully for $id" -ForegroundColor Green

    }
    catch{
        Write-Host "Issue occured when updating the asset security. Error: $($_.exception.message)" -ForegroundColor Red
        
        continue
    }
    

}

################## Enable restriction flag ###########

function restrict_asset {

    param (
        [string]$type,
        [string]$id,
        [string]$org_id
    )

    $name_url = "https://api.itglue.com/$type/$id"


$body = @"
{
    "data": {
        "type": "$type",
        "attributes": {
            "restricted": true
        }
    }
}
"@

    try{

        $name = Invoke-RestMethod  -Uri $name_url -Method 'PATCH' -Headers $headers -Body $body

        Write-Host "Restricting the asset." -ForegroundColor Cyan

        update_asset_security -type $type -id $id

        add_to_csv -id $id -type $type


    }catch{
    
        Write-Host "Issue occured when restricting the asset with ID: $id. Error: $($_.exception.message)" -ForegroundColor Red

        continue
    }
}

################### Update Doc Folder name ################

function update_df_security {

    param (
        [string]$id,
        [string]$type,
        [string]$df_org
    )

    $df_url = "https://api.itglue.com/organizations/$df_org/relationships/$type/$id"


$body = @"
{
    "data": {
        "type": "$type",
        "attributes": {
            "restricted": true
        }
    }
}
"@

    try{

        $name = Invoke-RestMethod  -Uri $df_url -Method 'PATCH' -Headers $headers -Body $body

        Write-Host "Names updated successfully and restricting $type" -ForegroundColor Magenta

        update_asset_security -type $type -id $id

        add_df_csv -id $id -org_id $df_org -type $type

    }catch{
    
        Write-Host "Issue occured when updating the asset name or restricting the asset with ID: $id. Error: $($_.exception.message)" -ForegroundColor Red

        continue
    }
}

#################### Lookup MyGlue Flexible assets ####################


function lookup_fa {


    try{
    
        $fat = Invoke-RestMethod 'https://api.itglue.com/flexible_asset_types?page[size]=1000' -Method 'GET' -Headers $headers

        foreach ($template in $($fat.data)){

            $fa_url = "https://api.itglue.com/flexible_assets?filter[flexible-asset-type-id]=$($template.id)"
        
            try{
            
                $fa_asset = Invoke-RestMethod -Uri $fa_url -Method 'GET' -Headers $headers

                if ($($fa_asset.meta.'total-count') -eq $null){

                    Write-Host "No assets found under $($template.attributes.name)"
            
                }else{

                    foreach ($flex_asset in $($fa_asset.data)){
            
                        if ($($flex_asset.attributes.'my-glue') -eq $true){

                
                            Write-Host "Found MyGlue flexible asset with ID: $($flex_asset.id) and Name: $($flex_asset.attributes.name)! Cannot add notes or update the name to determine that this is MyGlue data"

                            restrict_asset -type 'flexible_assets' -id $($flex_asset.id) -org_id $($flex_asset.attributes.'organization-id')

                      

                            

                        }
                    }
                }
            
            
            }catch{
            
                Write-Host "Unable to find any flexible asset. Error: $($_.exception.message)" -ForegroundColor Red
            
            }
        
        }
    
    }catch{

        Write-Host "Unable to find any flexible asset template. Error: $($_.exception.message)" -ForegroundColor Red
    
    }

    Write-Host "_____________________________________________________________________________________________________________"

    Write-Host "Done processing flexible assets! Thank you for your support! Please cross check. Also, remember to request all MyGlue user to export their personal passwords manually from MyGlue portal!" -ForegroundColor Green

    Write-Host "_____________________________________________________________________________________________________________"


    Write-Host "Saving the CSV file name records.csv........ Location: C:\Users\{profile_name}\records.csv" -ForegroundColor Magenta

    Write-Host "______________________End of the script______________________________________________________________________"

}

#################### Lookup MyGlue core assets ########################

function lookup_myglue_assets {

    $resource_type = ('contacts','configurations','domains','passwords','locations','ssl_certificates','documents','document_folders','password_folders')

    foreach ($type in $resource_type) {


    if($type -eq 'documents'){



        Write-Host "Looking for Documents....." -ForegroundColor Yellow


        $Global:get_org = Invoke-RestMethod 'https://api.itglue.com/organizations' -Method 'GET' -Headers $headers

        foreach ($org in $($get_org.data)){
    
            $doc_lookup_url = "https://api.itglue.com/organizations/$($org.id)/relationships/documents" + "?age[size]=1000"


            try{

                $doc_looked_up_assets = Invoke-RestMethod -Uri $doc_lookup_url -Method 'GET' -Headers $headers

                foreach ($doc in $($doc_looked_up_assets.data)){

                    if($($doc.attributes.'my-glue') -eq $true){

                        Write-Host "Found MyGlue document with ID: $($doc.id) and Name: $($doc.attributes.name)! Appending (MyGlue Data) to the asset name"

                        restrict_asset -type $type -id $($doc.id) -org_id $($doc.attributes.'organization-id')
        
  

                    }

                }
        
            }
            catch{
                Write-Host "Unable to find any documents. Error: $($_.exception.message)" -ForegroundColor Red

            }

        }

    }

    elseif ($type -eq 'document_folders' -or $type -eq 'password_folders'){
    
        Write-Host "Looking for $type....." -ForegroundColor Yellow


        foreach ($orgs in $($get_org.data)){
    
            $df_lookup_url = "https://api.itglue.com/organizations/$($orgs.id)/relationships/$type" + "?age[size]=1000"


            try{

                $df_looked_up_assets = Invoke-RestMethod -Uri $df_lookup_url -Method 'GET' -Headers $headers

                foreach ($df in $($df_looked_up_assets.data)){
                    
                    if ($($df.attributes.'my-glue') -eq $true){
    
                        Write-Host "Found MyGlue $type with ID: $($df.id) and Name: $($df.attributes.name)! Appending (MyGlue Data) to the asset name"
                        
                        update_df_security -id $($df.id) -name $($df.attributes.name) -type $type  -df_org $($orgs.id)

                    }

                }
        
            }
            catch{
                Write-Host "Unable to find any document folders. Error: $($_.exception.message)" -ForegroundColor Red

            }

        }
    
    
    }

    else{
        try{

            $lookup_url = "https://api.itglue.com/$type" + "?page[size]=1000"

            $looked_up_assets = Invoke-RestMethod -Uri $lookup_url -Method 'GET' -Headers $headers

            Write-Host "Checking for any MyGlue $type......." -ForegroundColor Yellow

            }

                    
        catch {
                Write-Host "Problem occured when looking for the asset with ID: $($asset.id) and name: $($asset.attributes.name). Error: $($_.exception.message)" -ForegroundColor Red

                continue

        }

        if ($($looked_up_assets.meta.'total-count') -eq $null){

             Write-Host "No assets found under $type"
            
          }
          else{

                foreach ($asset in $($looked_up_assets.data)){
            
                    if ($($asset.attributes.'my-glue') -eq $true -and $($asset.attributes.personal) -in $null, $false){


                        if ($type -in 'configurations','contacts','passwords','locations'){

                            Write-Host "Found MyGlue asset with ID: $($asset.id) and Name: $($asset.attributes.name)! Adding to CSV file!"

                            restrict_asset -type $type -id $($asset.id) -org_id $($asset.attributes.'organization-id')

                        
                        }
                        else{
                        
                            Write-Host "Found MyGlue $type with ID: $($asset.id) and Name: $($asset.attributes.name)! Adding to CSV file"

                            
                            update_asset_security -type $type -id $($asset.id)

                            add_to_csv -id $($asset.id) -type $type

                        
                        }

                    }
            
                }
            }


    }

    }

    Write-Host "________________________________________________________________________________________________"

    Write-Host "Done processing the core assets. Looking for Flexible assets....." -ForegroundColor DarkYellow

    Write-Host "________________________________________________________________________________________________"


    lookup_fa
}

################### Request Information ##########################

function request_data {

    if ($email -eq $null) {
        $email = Read-Host -Prompt "Enter your MyGlue username"
    }

    if ($password -eq $null) {

        $maskpassword = Read-Host "Enter your MyGlue password" -AsSecureString

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($maskpassword)

        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }

    $Global:ITG_group_id = Read-Host -Prompt "Please insert your IT Glue Groups ID (Ask from IT Glue user. Admin > Groups > Edit the group > You will find the ID in URL)"
    
    $otp = Read-Host -Prompt "Enter your IT Glue OTP"

    
     if ($otp -eq $null){
     
        authorization_token -email "$email" -password "$password"

        lookup_myglue_assets
     
     }else{

        authorization_token -email "$email" -password "$password" -otp "$otp"

        lookup_myglue_assets
    }

}

#################### Headers #########################

if ($access_token -eq $null){
    
    Write-Host "Access token required!" -ForegroundColor Yellow

    $access_token = request_data
    

}