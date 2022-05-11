BEGIN {
  if (!download_dir) {
    system("echo \"You must specify a download directory with -v download_dir=<path>.\" 1>&2")
    exit 1
  }

  sub(/.+\/$/, "", download_dir)
}

{
  if ($1 ~ /\.git$/) {
    if (!$2) {
      system("echo \"You must specify a branch for the git repository " $1 ".\" 1>&2")
      exit 1
    }
    else if (!$3) {
      system("echo \"You must specify a directory for the git repository " $1 ".\" 1>&2")
      exit 1
    }
    else {
      pkg_path =  download_dir "/" $3
      pkg_file =  pkg_path ".tar.gz"

      if ((getline _ < pkg_file) >= 0) {
        system("echo \"Git repository archive '" pkg_file "' is already present; repository will not be cloned.\" 1>&2")
        system("echo 1>&2")
        next
      }

      git_files_path = "\"" pkg_path "/.git\""
      pkg_path = "\"" pkg_path "\""
      pkg_file = "\"" pkg_file "\""

      if (system("git clone --branch " $2 " --depth 1 " $1 " " pkg_path \
                 " && tar --xform='s:^" download_dir "/::' --exclude=" \
                 git_files_path " -czvf " pkg_file " " pkg_path " && rm -rf " \
                 pkg_path)) {
        exit 1
      }
    }
  }
  else {

    pkg_file = $2 ? (download_dir "/" $2) : ""

    if (pkg_file && (getline _ < pkg_file) >= 0) {
      system("echo \"User specified file '" pkg_file "' is already present; not downloading.\" 1>&2")
      system("echo 1>&2")
      next
    }

    pkg_file = pkg_file ? ("--output-document \"" pkg_file "\" ") : ""
    if (system("wget --no-clobber -P \"" download_dir "\" " pkg_file $1)) {
       exit 1
    }
  }
}
