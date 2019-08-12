<?php
header("Content-Type: text/plain");

require_once("config.inc.php");

set_time_limit(0);

if (!strlen(REGENERATE_SECRET))
{
	die("Please set REGENERATE_SECRET in config.inc.php!");
}

if (!isset($_GET['secret']) || $_GET['secret'] != REGENERATE_SECRET)
{
	die("Secret phrase is invalid. Sorry.");
}

$icons_path = INFO_PATH . "/icons";
if (!file_exists($icons_path))
{
	if (!@mkdir($icons_path, 0777))
		die("Insufficient permissions to " . INFO_PATH . " - cannot create Icons directory. Please check the permissions, they should allow Web server to create files.");
}

// Let's regenerate the indeces.
foreach ($POSSIBLE_FIRMWARE_VERSIONS as $fw_version)
{
	$os_version = $fw_version;
	GenerateIndex($fw_version);
}

CleanupOld();

print "All done, thank you!";

exit;

function GenerateIndex($os_version)
{
	print "Generating index for firmware $os_version.\n";

	$dirname = INFO_PATH;
		
	$no_symlink = true;
	
	$index = generate_index($dirname, INFO_PATH_URL);
	
	$INDEX = fopen($dirname."/index-" . $os_version . ".plist", "w");
	if ($INDEX)
	{
		fwrite($INDEX, $index);
		fclose($INDEX);
		chmod($dirname."/index-" . $os_version . ".plist", 0666);
	}
	
	print "\n";
}

function CleanupOld()
{
	$dir = opendir(INFO_PATH);
	if (!$dir)
		return;
	
	while ($file = readdir($dir))
	{
		$fullpath = INFO_PATH.'/'.$file;
		
		if ($file != '.' && $file != '..' && $file != 'icons')
		{
			$t = filemtime($fullpath);
			
			if ($t < (time() - CACHE_OLD_TTL))
			{
				print "Cleanup: $fullpath\n";
				
				if (is_dir($fullpath))
				{
					$handle = opendir($fullpath);
					for (;false !== ($file = readdir($handle));) if($file != "." && $file != "..") unlink($fullpath.'/'.$file);
					closedir($handle);
					rmdir($fullpath);
				}
				else
					unlink($fullpath);
			}
		}
	}
}

function generate_index($info_path, $info_url)
{
	global $index;
	global $packages;
	
	$index = new DOMDocument();
	$index->load('Info.plist');
	$element = $index->getElementsByTagName('dict');
	$repoInfo = $element->item(0);

	$repoInfo->appendChild($index->createElement('key', 'packages'));
	$packages = $index->createElement('array');
	$repoInfo->appendChild($packages);

	gather_categories($info_path, $info_url);

	return $index->saveXML();
}

function gather_categories($info_path, $info_url)
{
	$dir = opendir(PACKAGES_PATH);
	if ($dir)
	{
		while ($path = readdir($dir))
		{
			if (substr($path, 0, 1) == '.')
				continue;
			
			// traverse category
			scan_category(PACKAGES_PATH . "/" . $path, $path, $info_path, $info_url);
		}
	}
	
	closedir($dir);
}

function scan_category($path, $category, $info_path, $info_url)
{
	global $packages, $index, $os_version;
	
	$dir = opendir($path);
	if (!$dir)
		return;
		
	$packages_added = 0;
	$versions_skipped = 0;
	
	print "Scanning category '$category'...\n";
	
	$packages_to_add = array();
	
	while ($file = readdir($dir))
	{
		$fullpath = $path.'/'.$file;
		
		if (pathinfo($fullpath, PATHINFO_EXTENSION) == 'zip')
		{
			$pkgInfo = trim(get_from_zip($fullpath, 'Install.plist'));
			
			if (!$pkgInfo || !strlen($pkgInfo))
			{
				print "WARNING: Cannot add package $fullpath because Install.plist cannot be extracted.\n";
			}
			
			if ($pkgInfo and strlen($pkgInfo))
			{
				$package = new DOMDocument;
				$package->loadXML($pkgInfo);
				
				$r = parsePlist($package);
				
				if (!ConvertVersionStr($r['version']))		// Sanity checking of the version number
				{
					print "WARNING: Cannot add package $fullpath because version string (".$r['version'].") is malformed.\n";
					continue;
				}	
					
				if (isset($r['minOSRequired']))
				{
					if (ConvertVersionStr($os_version) < ConvertVersionStr($r['minOSRequired']))
						continue;
				}
				
				if (!isset($r['identifier']) && isset($r['bundleIdentifier']))
					$r['identifier'] = $r['bundleIdentifier'];
					
				if (isset($r['bundleIdentifier']))
					unset($r['bundleIdentifier']);
				
				if (isset($packages_to_add[$r['identifier']]))
				{
					// check version
					$existing_version = ConvertVersionStr($packages_to_add[$r['identifier']]['version']);
					$current_version = ConvertVersionStr($r['version']);
					$existing_revision = ConvertRevision($packages_to_add[$r['identifier']]['version']);
					$current_revision = ConvertRevision($r['version']);
					
					if ($existing_version > $current_version)
					{
						$versions_skipped++;
						continue;
					}
					
					if ($existing_version == $current_version && $existing_revision >= $current_revision)
					{
						$versions_skipped++;
						continue;
					}
				}
				
				$r['fullpath'] = $fullpath; // don't forget to remove this
				$r['package'] = $package;
				$r['file'] = $file;
				
				$packages_to_add[$r['identifier']] = $r;
			}
		}
	}
	
	foreach ($packages_to_add as $r)
	{
		$fullpath = $r['fullpath'];
		$package = $r['package'];
		$file = $r['file'];
		
		unset($r['package']);		// remove unneeded entries from the array
		unset($r['fullpath']);
		unset($r['file']);
		
		$dict = $package->createElement('dict');
		
		// Category
		$dict->appendChild($package->createElement('key', 'category'));
		$dict->appendChild($package->createElement('string', htmlspecialchars($category, ENT_QUOTES, 'UTF-8')));
		
		// Package date
		$dict->appendChild($package->createElement('key', 'date'));
		$dict->appendChild($package->createElement('string', filemtime($fullpath)));
		
		// Package ID
		$dict->appendChild($package->createElement('key', 'identifier'));
		$dict->appendChild($package->createElement('string', htmlspecialchars($r['identifier'], ENT_QUOTES, 'UTF-8')));
		
		// Package Name
		$dict->appendChild($package->createElement('key', 'name'));
		$dict->appendChild($package->createElement('string', htmlspecialchars($r['name'], ENT_QUOTES, 'UTF-8')));

		// Package Version
		$dict->appendChild($package->createElement('key', 'version'));
		$dict->appendChild($package->createElement('string', htmlspecialchars($r['version'], ENT_QUOTES, 'UTF-8')));
		
		// Package Description
		$dict->appendChild($package->createElement('key', 'description'));
		$dict->appendChild($package->createElement('string', htmlspecialchars($r['description'], ENT_QUOTES, 'UTF-8')));

		if (@$r['icon'])
		{
			$dict->appendChild($package->createElement('key', 'icon'));
			$dict->appendChild($package->createElement('string', htmlspecialchars($r['icon'], ENT_QUOTES, 'UTF-8')));					
		}
		else
		{	// Check the icon
			$icon_file = get_from_zip($fullpath, 'Install.png');
			if ($icon_file && INCLUDE_ICONS)
			{
				$icon_file_name = $r['identifier'] . "-" . $r['version'] . ".png";
				$icons_path = INFO_PATH . "/icons";
				@mkdir($icons_path, 0777);
				
				$FILE = fopen($icons_path . '/' . $icon_file_name, "w");
				if ($FILE)
				{
					fwrite($FILE, $icon_file);
					fclose($FILE);
					chmod($icons_path . '/' . $icon_file_name, 0666);
				}

				$r['icon'] = INFO_PATH_URL . 'icons/' . $icon_file_name;
				$dict->appendChild($package->createElement('key', 'icon'));
				$dict->appendChild($package->createElement('string', htmlspecialchars($r['icon'], ENT_QUOTES, 'UTF-8')));	
			}
		}				

		// And finally, more info location :)
		$more_info_filename = rawurlencode($r['identifier']) . "-" . rawurlencode($r['version']) . "-" . $os_version . ".plist";
		
		$dict->appendChild($package->createElement('key', 'url'));
		$dict->appendChild($package->createElement('string', htmlspecialchars($info_url . $more_info_filename, ENT_QUOTES, 'UTF-8')));
		
		$child = $index->importNode($dict, true);
		$packages->appendChild($child);
		
		// And since we're at it, create the more info plist for the package
		$r['size'] = filesize($fullpath);
		$r['hash'] = md5_file($fullpath);
		$r['location'] = PACKAGES_PATH_URL . rawurlencode($category) . "/" . rawurlencode($file);
		unset($r['scripts']);
						
		// Spool it into the more info file
		$FILE = fopen($info_path . '/' . $more_info_filename, "w");
		if ($FILE)
		{
			fwrite($FILE, _plist_output($r));
			fclose($FILE);
			chmod($info_path . '/' . $more_info_filename, 0666);
		}
		
		$packages_added++;		
	}
	
	print "Category '$category' scanned, $packages_added packages added, $versions_skipped packages skipped.\n";
}

function get_from_zip($zip_path, $filename)                                                                                                                                                                                                   
{                                                                                                                                                                                                                                             
	if (function_exists('shell_exec'))                                                                                                                                                                                                            
	{                                                                                                                                                                                                                                             
	    $result = shell_exec('unzip -pC ' . escapeshellarg($zip_path) . ' ' . escapeshellarg($filename));                                                                                                                                     
	}                                                                                                                                                                                                                                             
	else                                                                                                                                                                                                                                          
	{                                                                                                                                                                                                                                             
		$zip = new ZipArchive;                                                                                                                                                                                                                
		$res = $zip->open($zip_path);                                                                                                                                                                                                         
		if ($res === true)
		{                                                                                                                                                                                                                  
			$result = $zip->getFromName($filename);                                                                                                                                                                                               
                                                                                                                                                                                                                                     
			$zip->close();                                                                                                                                                                                                                        
		}                                                                                                                                                                                                                                                                                                                                                                                                                                                               
		else                                                                                                                                                                                                                                  
		{                                                                                                                                                                                                                                     
			echo "Error: Zip Error";                                                                                                                                                                                                              		
		}                                                                                                                                                                                                                                  
	}                                                                                                                                                                                                                                         

	return $result;                                                                                                                                                                                                                       
}

// parsing

function parsePlist( $document ) {
  $plistNode = $document->documentElement;

  $root = $plistNode->firstChild;

  // skip any text nodes before the first value node
  while ( $root->nodeName == "#text" ) {
    $root = $root->nextSibling;
  }

  return parseValue($root);
}

function parseValue( $valueNode ) {
  $valueType = $valueNode->nodeName;

  $transformerName = "parse_$valueType";

  if ( is_callable($transformerName) ) {
    // there is a transformer function for this node type
    return call_user_func($transformerName, $valueNode);
  }

  // if no transformer was found
  return null;
}

function parse_integer( $integerNode ) {
	return $integerNode->textContent;
}

function parse_string( $stringNode ) {
	return $stringNode->textContent;
}

function parse_date( $dateNode ) {
	return $dateNode->textContent;
}

function parse_true( $trueNode ) {
	return true;
}

function parse_false( $trueNode ) {
	return false;
}

function parse_dict( $dictNode ) {
  $dict = array();

  // for each child of this node
  for (
    $node = $dictNode->firstChild;
    $node != null;
    $node = $node->nextSibling
  ) {
    if ( $node->nodeName == "key" ) {
      $key = $node->textContent;

      $valueNode = $node->nextSibling;

      // skip text nodes
      while ( $valueNode->nodeType == XML_TEXT_NODE ) {
        $valueNode = $valueNode->nextSibling;
      }

      // recursively parse the children
      $value = parseValue($valueNode);

      $dict[$key] = $value;
    }
  }

  return $dict;
}

function parse_array( $arrayNode ) {
  $array = array();

  for (
    $node = $arrayNode->firstChild;
    $node != null;
    $node = $node->nextSibling
  ) {
    if ( $node->nodeType == XML_ELEMENT_NODE ) {
      array_push($array, parseValue($node));
    }
  }

  return $array;
}

// Converting back

function _plist_output($plist, $full = true, $in_array = false)
{
	$c = '';
	
	foreach ($plist as $key => $value)
	{
		if (!$in_array)
			$c .= "<key>".htmlspecialchars($key, ENT_NOQUOTES, 'utf-8')."</key>\n";
		if (is_bool($value))
		{
			if ($value)
				$c .= "<true/>\n";
			else
				$c .= "<false/>\n";
		}
		else if (is_int($value))
		{
			$c .= "<integer>$value</integer>\n";
		}
		else if (is_float($value))
		{
			$c .= "<float>$value</float>\n";
		}
		else if (is_array($value))
		{
			// we got two types of arrays, numeric ones, and keyed ones, which we interpret as dictionary.
			// lets figure out which one is it
			$has_symbolic_keys = false;
			
			foreach (array_keys($value) as $key)
			{
				if (!is_numeric($key))
					$has_symbolic_keys = true;
			}
			
			if ($has_symbolic_keys)
				$c .= "<dict>\n";
			else
				$c .= "<array>\n";
			
			$c .= _plist_output($value, false, !$has_symbolic_keys);
			
			if ($has_symbolic_keys)
				$c .= "</dict>\n";
			else
				$c .= "</array>\n";
		}
		else if (is_object($value) and is_a($value, "BLOB"))
		{
			$c .= "<data>\n";
			$c .= base64_encode($value->data);
			$c .= "\n</data>\n";
		}
		else
			$c .= "<string>" . htmlspecialchars($value, ENT_NOQUOTES, 'utf-8')."</string>\n";
	}
	
	if ($full)
	{
		$final = '<?xml version="1.0" encoding="UTF-8"?>';
		$final .= "\n";
		$final .= '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">';
		$final .= "\n";
		$final .= '<plist version="1.0">';
		$final .= "\n";
		$final .= "<dict>\n";
		$final .= $c;
		$final .= "</dict>\n</plist>\n";
		return $final;
	}
	else
		return $c;
}

function ConvertRevision($v)
{
	if (($foundpos = @strpos($v, '-', strlen($v)-5)) !== false)
	{
		$v = substr($v, $foundpos+1);
		
		return intval($v);
	}
	
	return 0;
}

// This is a direct port from C code of a CoreFoundation routine

function ConvertVersionStr($v)
{
	// cut off revision number from the version string
	if (($foundpos = @strpos($v, '-', strlen($v)-5)) !== false)
	{
		$v = substr($v, 0, $foundpos);
	}
	
	$DEVELOPMENT_STAGE = 0x20;
	$ALPHA_STAGE = 0x40;
	$BETA_STAGE = 0x60;
	$RELEASE_STAGE = 0x80;

	$major1 = 0;
	$major2 = 0;
	$minor1 = 0;
	$minor2 = 0;
	$minor1_2 = 0;
	$minor2_2 = 0;
	$stage = $RELEASE_STAGE;
	$build = 0;
	
	$versChars = '';
	$len = 0;
	$theVers = 0;
	$digitsDone = false;
	
	$len = strlen($v);
	
	if (($len == 0) || ($len > 12))
		return 0;
	
	// Parse version number from string.
    // String can begin with "." for major version number 0.  String can end at any point, but elements within the string cannot be skipped.
     
    // Get major version number.
	$idx = 0;
	
    $major1 = $major2 = 0;
    if (is_numeric(substr($v, $idx, 1))) {
        $major2 = intval(substr($v, $idx, 1));
        $idx++;
        $len--;
        if ($len > 0) {
            if (is_numeric(substr($v, $idx, 1))) {
                $major1 = $major2;
                $major2 = intval(substr($v, $idx, 1));
		        $idx++;
		        $len--;
                if ($len > 0) {
                    if (substr($v, $idx, 1) == '.') {
				        $idx++;
				        $len--;
                    } else {
                        $digitsDone = true;
                    }
                }
            } else if (substr($v, $idx, 1) == '.') {
 		        $idx++;
		        $len--;
            } else {
                $digitsDone = true;
            }
        }
    } else if ((substr($v, $idx, 1)) == '.') {
        $idx++;
        $len--;
    } else {
       $digitsDone = true;
    }

    // Now major1 and major2 contain first and second digit of the major version number as ints.
    // Now either len is 0 or chars points at the first char beyond the first decimal point.

    // Get the first minor version number.  
    if ($len > 0 && !$digitsDone) {
	    if (is_numeric(substr($v, $idx, 1))) {
	        $minor1_2 = intval(substr($v, $idx, 1));
	        $idx++;
	        $len--;
	        if ($len > 0) {
	            if (is_numeric(substr($v, $idx, 1))) {
	                $minor1 = $minor1_2;
	                $minor1_2 = intval(substr($v, $idx, 1));
			        $idx++;
			        $len--;
	                if ($len > 0) {
	                    if (substr($v, $idx, 1) == '.') {
					        $idx++;
					        $len--;
	                    } else {
	                        $digitsDone = true;
	                    }
	                }
	            } else if (substr($v, $idx, 1) == '.') {
	 		        $idx++;
			        $len--;
	            } else {
	                $digitsDone = true;
	            }
	        }
	    } else if ((substr($v, $idx, 1)) == '.') {
	        $idx++;
	        $len--;
	    } else {
	       $digitsDone = true;
	    }
    }

    // Now minor1 contains the first minor version number as an int.
    // Now either len is 0 or chars points at the first char beyond the second decimal point.

    // Get the second minor version number. 
    if ($len > 0 && !$digitsDone) {
	    if (is_numeric(substr($v, $idx, 1))) {
	        $minor2_2 = intval(substr($v, $idx, 1));
	        $idx++;
	        $len--;
	        if ($len > 0) {
	            if (is_numeric(substr($v, $idx, 1))) {
	                $minor2 = $minor2_2;
	                $minor2_2 = intval(substr($v, $idx, 1));
			        $idx++;
			        $len--;
	                if ($len > 0) {
	                    $digitsDone = true;
	                }
	            } else {
	                $digitsDone = true;
	            }
	        }
	    } else {
	       $digitsDone = true;
	    }
    }

    // Now minor2 contains the second minor version number as an int.
    // Now either len is 0 or chars points at the build stage letter.

    // Get the build stage letter.  We must find 'd', 'a', 'b', or 'f' next, if there is anything next.
    if ($len > 0) {
        if (substr($v, $idx, 1) == 'd') {
            $stage = $DEVELOPMENT_STAGE;
        } else if (substr($v, $idx, 1) == 'a') {
            $stage = $ALPHA_STAGE;
        } else if (substr($v, $idx, 1) == 'b') {
            $stage = $BETA_STAGE;
        } else if (substr($v, $idx, 1) == 'f') {
            $stage = $RELEASE_STAGE;
        } else if (substr($v, $idx, 1) == 'v') {
           $stage = $RELEASE_STAGE;
       } else {
            return 0;
        }
        $idx++;
        $len--;
    }

    // Now stage contains the release stage.
    // Now either len is 0 or chars points at the build number.

    // Get the first digit of the build number.
    if ($len > 0) {
        if (is_numeric(substr($v, $idx, 1))) {
            $build = intval(substr($v, $idx, 1));
	        $idx++;
	        $len--;
        } else {
            return 0;
        }
    }
    // Get the second digit of the build number.
    if ($len > 0) {
        if (is_numeric(substr($v, $idx, 1))) {
            $build *= 10;
            $build += intval(substr($v, $idx, 1));
	        $idx++;
	        $len--;
        } else {
            return 0;
        }
    }
    // Get the third digit of the build number.
    if ($len > 0) {
        if (is_numeric(substr($v, $idx, 1))) {
            $build *= 10;
            $build += intval(substr($v, $idx, 1));
	        $idx++;
	        $len--;
        } else {
            return 0;
        }
    }

    // Range check the build number and make sure we exhausted the string.
    if (($build > 0xFF) || ($len > 0)) return 0;

	//					 00  00  00  00  00  00  80  FF
	$theVers = sprintf("%01d%01d%01d%01d%01d%01d%02X%02X", $major1, $major2, $minor1, $minor1_2, $minor2, $minor2_2, $stage, $build);
	
    return $theVers;
}
?>