# VS Code AppImage Builder

A lightweight Bash script to automatically build a portable [AppImage](https://appimage.org/) for [Visual Studio Code](https://code.visualstudio.com/) from the official release.

## ✨ Features

- Downloads the latest stable or Insiders release of Visual Studio Code from the official site
- Extracts the `.tar.gz` package contents
- Assembles a clean AppDir structure for AppImage
- Automatically downloads `appimagetool` if not available
- Builds an AppImage using `appimagetool`
- Creates a `.desktop` file and icon for menu integration
- Installs a desktop entry for the current user
- Cleans up all temporary files after build
- Supports `--verbose` mode for detailed output
- Supports `--insider` to build VS Code Insiders edition

## 🚀 Usage


```bash
./build-vscode-appimage.sh [--verbose] [--insider]
```

> The resulting AppImage file will be created in your current working directory.

### Options

- `--verbose`   Show detailed output during the build process
- `--insider`   Build the Insiders (preview) version of Visual Studio Code

## How it works

1. Downloads the latest VS Code (or Insiders) tarball for Linux x64
2. Extracts the contents and prepares the AppDir structure
3. Downloads `appimagetool` if not found on the system
4. Builds the AppImage file in your current directory
5. Installs a desktop entry and icon for easy launching from your menu
6. Cleans up all temporary files

## License

MIT License
