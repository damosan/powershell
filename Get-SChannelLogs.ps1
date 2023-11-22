# Script to get SChannel logs on a windows host, to determine tls version and ciphers in use.  Requires SChannel logging to be increased.
# Highest level of "0000007" ensures nothing is missed.
#
# https://learn.microsoft.com/en-us/windows-server/security/tls/tls-registry-settings?tabs=diffie-hellman

function Get-Cipher {
    Param (
        [string]$hex_code
    )

    $hex_code = $hex_code.ToUpper()
    # Removed leading zeros from hex code to match output in SChannel logging in Windows systems.
    # Ref : https://www.ibm.com/docs/en/datapower-gateway/2018.4?topic=scpc-ciphers
    $ciphers = @{
        "0x1"    = "RSA_WITH_NULL_MD5";
        "0x2"    = "RSA_WITH_NULL_SHA";
        "0x3"    = "RSA_EXPORT_WITH_RC4_40_MD5";
        "0x4"    = "RSA_WITH_RC4_128_MD5";
        "0x5"    = "RSA_WITH_RC4_128_SHA";
        "0x6"    = "RSA_EXPORT_WITH_RC2_CBC_40_MD5";
        "0x8"    = "RSA_EXPORT_WITH_DES40_CBC_SHA";
        "0x9"    = "RSA_WITH_DES_CBC_SHA";
        "0xA"    = "RSA_WITH_3DES_EDE_CBC_SHA";
        "0x11"   = "DHE_DSS_EXPORT_WITH_DES40_CBC_SHA";
        "0x12"   = "DHE_DSS_WITH_DES_CBC_SHA";
        "0x13"   = "DHE_DSS_WITH_3DES_EDE_CBC_SHA";
        "0x14"   = "DHE_RSA_EXPORT_WITH_DES40_CBC_SHA";
        "0x15"   = "DHE_RSA_WITH_DES_CBC_SHA";
        "0x16"   = "DHE_RSA_WITH_3DES_EDE_CBC_SHA";
        "0x2F"   = "RSA_WITH_AES_128_CBC_SHA";
        "0x32"   = "DHE_DSS_WITH_AES_128_CBC_SHA";
        "0x33"   = "DHE_RSA_WITH_AES_128_CBC_SHA";
        "0x35"   = "RSA_WITH_AES_256_CBC_SHA";
        "0x38"   = "DHE_DSS_WITH_AES_256_CBC_SHA";
        "0x39"   = "DHE_RSA_WITH_AES_256_CBC_SHA";
        "0x3B"   = "RSA_WITH_NULL_SHA256";
        "0x3C"   = "RSA_WITH_AES_128_CBC_SHA256";
        "0x3D"   = "RSA_WITH_AES_256_CBC_SHA256";
        "0x40"   = "DHE_DSS_WITH_AES_128_CBC_SHA256";
        "0x67"   = "DHE_RSA_WITH_AES_128_CBC_SHA256";
        "0x6A"   = "DHE_DSS_WITH_AES_256_CBC_SHA256";
        "0x6B"   = "DHE_RSA_WITH_AES_256_CBC_SHA256";
        "0x9C"   = "RSA_WITH_AES_128_GCM_SHA256";
        "0x9D"   = "RSA_WITH_AES_256_GCM_SHA384";
        "0x9E"   = "DHE_RSA_WITH_AES_128_GCM_SHA256";
        "0x9F"   = "DHE_RSA_WITH_AES_256_GCM_SHA384";
        "0xA2"   = "DHE_DSS_WITH_AES_128_GCM_SHA256";
        "0xA3"   = "DHE_DSS_WITH_AES_256_GCM_SHA384";
        "0xC010" = "ECDHE_RSA_WITH_NULL_SHA";
        "0xC011" = "ECDHE_RSA_WITH_RC4_128_SHA";
        "0xC012" = "ECDHE_RSA_WITH_3DES_EDE_CBC_SHA";
        "0xC013" = "ECDHE_RSA_WITH_AES_128_CBC_SHA";
        "0xC014" = "ECDHE_RSA_WITH_AES_256_CBC_SHA";
        "0xC027" = "ECDHE_RSA_WITH_AES_128_CBC_SHA256";
        "0xC028" = "ECDHE_RSA_WITH_AES_256_CBC_SHA384";
        "0xC02F" = "ECDHE_RSA_WITH_AES_128_GCM_SHA256";
        "0xC030" = "ECDHE_RSA_WITH_AES_256_GCM_SHA384";
        "0xC006" = "ECDHE_ECDSA_WITH_NULL_SHA";
        "0xC007" = "ECDHE_ECDSA_WITH_RC4_128_SHA";
        "0xC008" = "ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA";
        "0xC009" = "ECDHE_ECDSA_WITH_AES_128_CBC_SHA";
        "0xC00A" = "ECDHE_ECDSA_WITH_AES_256_CBC_SHA";
        "0xC023" = "ECDHE_ECDSA_WITH_AES_128_CBC_SHA256";
        "0xC024" = "ECDHE_ECDSA_WITH_AES_256_CBC_SHA384";
        "0xC02B" = "ECDHE_ECDSA_WITH_AES_128_GCM_SHA256";
        "0xC02C" = "ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
    }

    return $ciphers[$hex_code]

}

# Main Code
$log_entries = @()
$logs = (Get-EventLog -LogName System | Where-Object { ($_.Source -ilike "Schannel") -and ($_.EventId -eq "36880") }) 
foreach ($entry in $logs) {
    $log_entry = $null
    $role = $null
    $protocol = $null
    $cipher_suite = $null
    $strenth = $null
    $target =$null
    $local_cert = $null

    $role = $entry.ReplacementStrings[0]
    $protocol = $entry.ReplacementStrings[1]
    $cipher_suite = Get-Cipher ($entry.ReplacementStrings[2])
    $strenth = $entry.ReplacementStrings[3]
    $target = $entry.ReplacementStrings[5]
    $local_cert = $entry.ReplacementStrings[6]

    $event_data = @{
        Role                = $role
        Protocol            = $protocol
        CipherSuite         = $cipher_suite
        Strength            = $strenth
        Target              = $target
        LocalCertificate    = $local_cert
    }

    # Create the custom object
    $log_entry = New-Object PSObject -Property $event_data
    # Add the custom object to the array
    $log_entries += $log_entry
}

$log_entries | Select-Object Role, Protocol, CipherSuite, Strength, Target, LocalCertificate
