function up --wraps='sudo pacman -Syu' --description 'alias up=sudo pacman -Syu'
  sudo pacman -Syu $argv
        
end
