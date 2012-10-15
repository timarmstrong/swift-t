package exm.stc.common.exceptions;

import exm.stc.frontend.Context;

public class VariableUsageException extends UserException {

  private static final long serialVersionUID = 1L;

  public VariableUsageException(String file, int line, int col, String message) {
    super(file, line, col, message);
  }

  public VariableUsageException(Context context, String message) {
    super(context, message);
  }

  public VariableUsageException(String message) {
    super(message);
  }

}
