# VS Code AppImage Builder

A lightweight Bash script to automatically build a portable [AppImage](https://appimage.org/) for [Visual Studio Code](https://code.visualstudio.com/) from the official release.

## ✨ Features

- Downloads the latest release of Visual Studio Code from the official site
- Extracts the `.deb` package contents
- Assembles a clean AppDir structure
- Builds an AppImage using `appimagetool`
- Works in your current working directory
- Supports `--verbose` mode for detailed output

## 🚀 Usage

```bash
./build-vscode-appimage.sh [--verbose]
```

## About

This script helps you create a portable AppImage for Visual Studio Code easily and quickly.

## License

MIT License
