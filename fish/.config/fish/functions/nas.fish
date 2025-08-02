function nas --wraps='ssh 192.168.178.186' --description 'alias nas=ssh 192.168.178.186'
  ssh 192.168.178.186 $argv
        
end
