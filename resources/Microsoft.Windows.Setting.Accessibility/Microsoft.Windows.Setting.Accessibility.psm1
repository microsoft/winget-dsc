[DSCResource()]
class MessageDuration {
    [DscProperty(Key)] [MessageDurationSeconds] $MessageDurationSetting = [MessageDurationSeconds]::KeepCurrentValue

    hidden [string] $MessageDurationProperty = 'MessageDuration'

    [MessageDuration] Get() {
        $currentState = [MessageDuration]::new()
        
		if (-not(DoesRegistryKeyPropertyExist -Path $global:MessageDurationRegistryPath -Name $this.MessageDurationProperty)) {
            $MessageSetting = [MessageDurationSeconds]::fiveSeconds
        } else {
			$MessageSetting = (Get-ItemProperty -Path $global:MessageDurationRegistryPath -Name $this.MessageDurationProperty).MessageDuration
			$currentState.MessageDurationSetting = switch ($MessageSetting) {
				5 { [MessageDurationSeconds]::fiveSeconds }
				7 { [MessageDurationSeconds]::sevenSeconds }
				15 { [MessageDurationSeconds]::fifteenSeconds }
				30 { [MessageDurationSeconds]::thirtySeconds }
				60 { [MessageDurationSeconds]::oneMinute }
				300 { [MessageDurationSeconds]::fiveMinutes }
				default { [MessageDurationSeconds]::KeepCurrentValue }
			}
				
		}
		
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($this.MessageDurationSetting -ne [MessageDurationSeconds]::KeepCurrentValue -and $this.MessageDurationSetting -ne $currentState.MessageDurationSetting) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.MessageDurationSetting -ne [MessageDurationSeconds]::KeepCurrentValue) {
            $desiredState = [MessageDurationSeconds]($this.MessageDurationSetting)

            if (-not (Test-Path -Path $global:PointerRegistryPath)) {
                New-Item -Path $global:PointerRegistryPath -Force | Out-Null
            }

            Set-ItemProperty -Path $global:MessageDurationRegistryPath -Name $this.MessageDurationProperty -Value $desiredState            
            
        }
    }
}
