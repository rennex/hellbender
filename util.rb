
module Hellbender
  module UtilMethods

    # handle UTF-8 and latin-1 encodings
    def guess_encoding(str)
      str.force_encoding("UTF-8")
      unless str.valid_encoding?
        str.encode!("UTF-8", "ISO-8859-1")
      end
    end

    # convert nicks to lowercase with IRC rules
    def irccase(name)
      name.to_s.downcase.tr('[]~\\', "{}^|")
    end

    # compare nicks / channel names case-insensitively
    def irccmp(name1, name2)
      if name1 && name2
        irccase(name1) == irccase(name2)
      end
    end

    # check that a nickname contains only allowed characters
    def valid_nick?(nick)
      nick.to_s.match(/\A(?![-0-9])[-a-z0-9\[\]\|`^{}\\_]+\z/i)
    end

    # raise an exception if the nickname isn't valid
    def validate_nick!(nick)
      unless valid_nick?(nick)
        raise ArgumentError, "invalid nickname: #{nick.inspect}"
      end
    end
  end

  class Util
    extend UtilMethods
  end

  module Sync
    def sync
      @mutex.synchronize { yield }
    end
  end
end
