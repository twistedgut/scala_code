
// @GENERATOR:play-routes-compiler
// @SOURCE:/vagrant/conf/routes
// @DATE:Fri Jul 10 16:02:14 UTC 2015

package controllers;

import router.RoutesPrefix;

public class routes {
  
  public static final controllers.ReverseAssets Assets = new controllers.ReverseAssets(RoutesPrefix.byNamePrefix());
  public static final controllers.ReverseDistributionCentreController DistributionCentreController = new controllers.ReverseDistributionCentreController(RoutesPrefix.byNamePrefix());
  public static final controllers.ReverseBoxesEndpoint BoxesEndpoint = new controllers.ReverseBoxesEndpoint(RoutesPrefix.byNamePrefix());
  public static final controllers.ReverseApplication Application = new controllers.ReverseApplication(RoutesPrefix.byNamePrefix());
  public static final controllers.ReverseQuantityController QuantityController = new controllers.ReverseQuantityController(RoutesPrefix.byNamePrefix());

  public static class javascript {
    
    public static final controllers.javascript.ReverseAssets Assets = new controllers.javascript.ReverseAssets(RoutesPrefix.byNamePrefix());
    public static final controllers.javascript.ReverseDistributionCentreController DistributionCentreController = new controllers.javascript.ReverseDistributionCentreController(RoutesPrefix.byNamePrefix());
    public static final controllers.javascript.ReverseBoxesEndpoint BoxesEndpoint = new controllers.javascript.ReverseBoxesEndpoint(RoutesPrefix.byNamePrefix());
    public static final controllers.javascript.ReverseApplication Application = new controllers.javascript.ReverseApplication(RoutesPrefix.byNamePrefix());
    public static final controllers.javascript.ReverseQuantityController QuantityController = new controllers.javascript.ReverseQuantityController(RoutesPrefix.byNamePrefix());
  }

}
