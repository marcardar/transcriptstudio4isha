xquery version "1.0";

module namespace admin-panel = "http://www.ishafoundation.org/ts4isha/xquery/admin-panel";

import module namespace media-fns = "http://www.ishafoundation.org/ts4isha/xquery/media-fns" at "media-fns.xqm";
import module namespace id-utils = "http://www.ishafoundation.org/ts4isha/xquery/id-utils" at "id-utils.xqm";
import module namespace utils = "http://www.ishafoundation.org/ts4isha/xquery/utils" at "utils.xqm";

declare namespace request = "http://exist-db.org/xquery/request";
declare namespace session = "http://exist-db.org/xquery/session";
declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace util = "http://exist-db.org/xquery/util";

declare function admin-panel:main() as element()*
{
if (utils:is-current-user-admin()) then	
	(
		<center><h2>Isha Foundation Transcript Administration</h2></center>
	,
		let $domain := request:get-parameter('domain', ())
		let $prefix := request:get-parameter('prefix', ())
		let $prefix :=
			if (empty($prefix) or $prefix eq '' or substring($prefix, string-length($prefix), 1) eq '-') then
				$prefix
			else
				concat($prefix, '-')
		let $uploadedFilename := request:get-uploaded-file-name("upload-media-metadata")
		return
		<div class="panel">
			<h3>Configure Database</h3>
			Click <a href="configure-database.xql">here</a> to add the event collections
			<h3>Find max ID</h3>
			<form id="find-max-id-form">
				<input type="hidden" name="panel" value="admin"/>
				<table id="find-max-id-form-table" cellpadding="2"><tr>
					<td>Domain</td>
					<td><select name="domain">
						{
						for $thisDomain in $id-utils:all-domains
						return
							<option value="{$thisDomain}">
							{if ($domain = $thisDomain) then attribute selected {'selected'} else ()}
							{$thisDomain}
							</option>
						}
					</select></td>
					<td>with prefix</td>
					<td><input type="text" name="prefix" size="5" value="{if (exists($prefix)) then $prefix else ()}"/></td>
					<td><input type="submit" value="Find"/></td> 
				</tr></table>
			</form>
			<h3>Upload Media Metadata</h3>
			<form id="upload-media-metadata-form" method="POST" enctype="multipart/form-data">
				<input type="hidden" name="panel" value="admin"/>
				<table id="upload-media-metadata-form-table" cellpadding="2"><tr>
					<td><input type="submit" value="Upload"/></td> 
                    <td>
                        <input type="file" size="30" name="upload-media-metadata"/>
                    </td>
				</tr></table>
			</form>
			<hr/>
			{
			if (exists($domain)) then
				admin-panel:process-find-max-id($domain, $prefix)
			else if (exists($uploadedFilename)) then
				admin-panel:process-upload-media-metadata($uploadedFilename)
			else
				()
			}			
		</div>
	)
else
	error((), 'Only admin user allowed to use admin panel')
};

declare function admin-panel:process-find-max-id($domain as xs:string, $prefix as xs:string?) as element()*
{
	if (not(exists($prefix)) or normalize-space($prefix) = '') then
		<span>Cannot specify blank prefix</span>
	else
		let $maxIdInteger := id-utils:get-max-id-integer($domain, $prefix)
		return
			if (empty($maxIdInteger)) then
				<p>No ids found for domain '{<b>{$domain}</b>}' with prefix '{<b>{$prefix}</b>}'</p>
			else
				if ($maxIdInteger < 0) then
					<p>{$domain}/@id does not support prefix: {$prefix}</p>
				else
					let $maxId := concat($prefix, $maxIdInteger)
					return
						<p>Max id for domain '{<b>{$domain}</b>}' with prefix '{<b>{$prefix}</b>}' is: {<b>{$maxId}</b>}</p>
};

declare function admin-panel:process-upload-media-metadata($uploadedFilename as xs:string) as element()*
{
	if ($uploadedFilename = '') then
		<span>No file specified</span>
	else
		let $uploadedFile := request:get-uploaded-file("upload-media-metadata")
		let $tempColl := utils:create-collection($utils:tempCollectionPath, true())
		let $tempFile := concat(util:uuid(), '.xml')
		let $tempPath := xdb:store($tempColl, $tempFile, $uploadedFile)
		let $doc := doc($tempPath)
		let $rootElementName := local-name($doc/*[1])
		let $result :=
			if ($rootElementName != 'mediaMetadata') then
				concat('Incorrect root element name: ', $rootElementName)
			else
				let $newMediaDetails :=
					for $deviceXML in $doc//device
					let $sessionId := $deviceXML/ancestor-or-self::*[exists(@sessionId)]/xs:string(@sessionId)
					let $mediaElementsToImport := $deviceXML/*
					let $importedMediaDetails := media-fns:import-media-elements($mediaElementsToImport, $sessionId, $deviceXML/@code)
					return
					(
						<h3>Session ID: {$sessionId}, Device Code: {$deviceXML/xs:string(@code)}</h3>
					,
						if (empty($importedMediaDetails)) then
							<p>Nothing imported</p>
						else
							<p>{
							for $importedMediaDetail in $importedMediaDetails
							return
								($importedMediaDetail, <br/>)
							}</p>
					)
				return
					$newMediaDetails
		let $null := xdb:remove($tempColl, $tempFile)
		return
			$result
};
