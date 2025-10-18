public class ParkLocator {

    public static String[] country(String country){
        ParkService.ParksImplPort sv = new ParkService.ParksImplPort ();
        return sv.byCountry(country);
    }
}