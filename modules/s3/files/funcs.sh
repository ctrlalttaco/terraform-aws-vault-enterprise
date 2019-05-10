#!/usr/bin/env bash

log() {
  local -r level="$1"
  local -r func="$2"
  local -r message="$3"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [${SCRIPT_NAME}:${func}] ${message}"
  [ "$level" == "ERROR" ] && exit 1
}

assert_not_empty() {
  local -r func="assert_not_empty"
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log "ERROR" "$func" "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

user_exists() {
  local -r func="user_exists"
  local -r user="$1"
  id "$user" >/dev/null 2>&1
}

create_user() {
  local -r func="create_user"
  local -r user="$1"
  local -r home="$2"

  if $(user_exists "$user"); then
    log "INFO" $func "User $user already exists..."
  else
    log "INFO" $func "Creating user $user..."
    useradd --system --home "$home" --shell /bin/false "$user"
  fi
}

ssm_parameter_exists() {
  local -r region="$1"
  local -r parameter="$2"

  aws ssm get-parameter --region "$region" --name "$parameter" &> /dev/null
  if [[ $? -eq 0 ]]
  then
    return 0
  else
    return 1
  fi
}

get_ssm_parameter() {
  local -r func="get_ssm_parameter"
  local -r region="$1"
  local -r parameter="$2"
  
  if $(ssm_parameter_exists $region $parameter)
  then
    log "INFO" $func "Retrieving SSM parameter $parameter..."
    aws ssm get-parameter --region "$region" --name "$parameter" --with-decryption | jq --raw-output '.Parameter.Value'
  else
    log "ERROR" $func "SSM parameter $parameter does not exist, exiting..."
  fi
}

put_ssm_parameter() {
  local -r func="get_ssm_parameter"
  local -r region="$1"
  local -r parameter="$2"
  local -r value="$3"
  
  if $(ssm_parameter_exists $region $parameter)
  then
    log "INFO" $func "SSM parameter $parameter already exists, doing nothing..."
  else
    log "INFO" $func "Creating SSM parameter $parameter..."
    aws ssm put-parameter --region "$region" --name "$parameter" --value "$value" --type "SecureString"
  fi
}