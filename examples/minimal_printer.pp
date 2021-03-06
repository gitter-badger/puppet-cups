include '::cups'

cups_queue { 'MinimalRaw':
  ensure => 'printer',
  uri    => 'lpd://192.168.2.105/binary_p1'
}

cups_queue { 'MinimalModel':
  ensure => 'printer',
  model  => 'drv:///sample.drv/generic.ppd',
  uri    => 'lpd://192.168.2.105/binary_p1'
}

cups_queue { 'MinimalPPD':
  ensure => 'printer',
  ppd    => '/usr/share/cups/model/myprinter.ppd',
  uri    => 'lpd://192.168.2.105/binary_p1'
}

cups_queue { 'MinimalInterface':
  ensure    => 'printer',
  interface => '/usr/share/cups/model/myprinter.sh',
  uri       => 'lpd://192.168.2.105/binary_p1'
}