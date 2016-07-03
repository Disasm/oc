<?php


function getDirContents($path, &$results = array()) {
  if (is_dir($path)) {
    $files = scandir($path);
    foreach($files as $key => $value){
      $new_path = realpath($path.DIRECTORY_SEPARATOR.$value);
      if($value != "." && $value != "..") {
        getDirContents($new_path, $results);
      }
    }
  } else if (is_file($path)) {
    $results[] = $path;
  }
  return $results;
}

if (!isset($_GET["action"])) {
  echo("READY");
  return;
}

$root_folder = dirname(__FILE__);
$files_root = $root_folder.DIRECTORY_SEPARATOR."files".DIRECTORY_SEPARATOR;
$action = $_GET["action"];
if ($action == "list") {

  $names = explode(",", $_GET["names"]);
  if ($_GET["names"] == "") {
    $names = array();
  }
  $results = array();
  foreach($names as $name) {
    $name = preg_replace('/[^a-zA-Z0-9-_\.\/]/', '', $name);
    $name = preg_replace('/\.\.+/', '', $name);  
  
    $full_path_requested = $files_root.$name;
    foreach(getDirContents($full_path_requested) as $full_path) {
      $path = substr($full_path, strlen($files_root));
      $hash = md5_file($full_path);
      $results[] = "  { path=\"$path\", hash=\"$hash\" }";
    }
  }
  print("{\n".implode(",\n", $results)."\n}");

} else {
  die("Invalid action.");
}



