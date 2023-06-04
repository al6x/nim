import base, keep/model/docm

export docm

type
  FBlockSource* = ref object of BlockTextSource
    text*, id*, args*: string