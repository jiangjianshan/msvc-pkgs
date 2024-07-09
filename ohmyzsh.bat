@echo off

setlocal enabledelayedexpansion

:: ohmyzsh
if not exist "!HOME!\.oh-my-zsh" (
  echo [%~nx0] Installing ohmyzsh
  git clone --single-branch -b master https://github.com/ohmyzsh/ohmyzsh.git !HOME!\.oh-my-zsh || goto :end
  copy /V /Y !HOME!\.oh-my-zsh\templates\zshrc.zsh-template !HOME!\.zshrc
  C:\cygwin64\bin\sed -i "s|ZSH_THEME=\"robbyrussell\"|ZSH_THEME=\"powerlevel10k\/powerlevel10k\"|g" !HOME:\=/!/.zshrc
  C:\cygwin64\bin\sed -i "s|plugins=(git)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|g" !HOME:\=/!/.zshrc
) else (
  echo [%~nx0] Updating ohmyzsh
  cd /d !HOME!\.oh-my-zsh
  git fetch origin master || goto :end
  git reset --hard origin/master || goto :end
)

:: powerlevel10k
if not exist "!HOME!\.oh-my-zsh\custom\themes\powerlevel10k" (
  echo [%~nx0] Installing powerlevel10k
  git clone --single-branch -b master https://github.com/romkatv/powerlevel10k.git !HOME!\.oh-my-zsh\custom\themes\powerlevel10k || goto :end
) else (
  echo [%~nx0] Updating powerlevel10k
  cd /d !HOME:\=/!\.oh-my-zsh/custom/themes/powerlevel10k
  git fetch origin master || goto :end
  git reset --hard origin/master || goto :end
)

:: zsh-autosuggestions
if not exist "!HOME!\.oh-my-zsh\custom\plugins\zsh-autosuggestions" (
  echo [%~nx0] Installing zsh-autosuggestions
  git clone --single-branch -b master https://github.com/zsh-users/zsh-autosuggestions !HOME!\.oh-my-zsh\custom\plugins\zsh-autosuggestions || goto :end
) else (
  echo [%~nx0] Updating zsh-autosuggestions
  cd !HOME:\=/!\.oh-my-zsh/custom/plugins/zsh-autosuggestions
  git fetch origin master || goto :end
  git reset --hard origin/master || goto :end
)

:: zsh-syntax-highlighting
if not exist "!HOME!\.oh-my-zsh\custom\plugins\zsh-syntax-highlighting" (
  echo [%~nx0] Installing zsh-syntax-highlighting
  git clone --single-branch -b master https://github.com/zsh-users/zsh-syntax-highlighting.git !HOME!\.oh-my-zsh\custom\plugins\zsh-syntax-highlighting || goto :end
) else (
  echo [%~nx0] Updating zsh-syntax-highlighting
  cd !HOME!\.oh-my-zsh\custom\plugins\zsh-syntax-highlighting
  git fetch origin master || goto :end
  git reset --hard origin/master || goto :end
)

:end
echo [%~nx0] Done.
